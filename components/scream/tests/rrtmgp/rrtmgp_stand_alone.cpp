#include <iostream>
#include <cmath>
#include <catch2/catch.hpp>

#include "control/atmosphere_driver.hpp"
#include "physics/rrtmgp/atmosphere_radiation.hpp"
#include "physics/rrtmgp/scream_rrtmgp_interface.hpp"
#include "physics/share/physics_only_grids_manager.hpp"
#include "share/atm_process/atmosphere_process.hpp"
#include "ekat/ekat.hpp"
#include "ekat/ekat_pack.hpp"
#include "ekat/ekat_parse_yaml_file.hpp"
#include "ekat/util/ekat_test_utils.hpp"
#include "ekat/kokkos/ekat_kokkos_utils.hpp"
#include "mo_gas_concentrations.h"
#include "mo_garand_atmos_io.h"
#include "Intrinsics.h"
#include "rrtmgp_test_utils.hpp"

/*
 * Run standalone test problem for RRTMGP and compare with baseline
 */

namespace scream {

  using KT = KokkosTypes<DefaultDevice>;
  using ExeSpace = KT::ExeSpace;
  using MemberType = KT::MemberType;
       
    /* 
     * Run standalone test through SCREAM driver this time
     */
    TEST_CASE("rrtmgp_scream_stand_alone", "") {
        using namespace scream;
        using namespace scream::control;

        // Get baseline name (needs to be passed as an arg)
        std::string inputfile = ekat::TestSession::get().params.at("rrtmgp_inputfile");
        std::string baseline = ekat::TestSession::get().params.at("rrtmgp_baseline");

        // Check if files exists
        REQUIRE(rrtmgpTest::file_exists(inputfile.c_str()));
        REQUIRE(rrtmgpTest::file_exists(baseline.c_str()));

        // Initialize yakl
        if(!yakl::isInitialized()) { yakl::init(); }

        // Read reference fluxes from baseline file
        real2d sw_flux_up_ref;
        real2d sw_flux_dn_ref;
        real2d sw_flux_dn_dir_ref;
        real2d lw_flux_up_ref;
        real2d lw_flux_dn_ref;
        rrtmgpTest::read_fluxes(baseline, sw_flux_up_ref, sw_flux_dn_ref, sw_flux_dn_dir_ref, lw_flux_up_ref, lw_flux_dn_ref );

        // Load ad parameter list
        std::string fname = "input.yaml";
        ekat::ParameterList ad_params("Atmosphere Driver");
        REQUIRE_NOTHROW ( parse_yaml_file(fname,ad_params) );
        // Create a MPI communicator
        ekat::Comm atm_comm (MPI_COMM_WORLD);

        // Need to register products in the factory *before* we create any atm process or grids manager.,
        auto& proc_factory = AtmosphereProcessFactory::instance();
        auto& gm_factory = GridsManagerFactory::instance();
        proc_factory.register_product("RRTMGP",&create_atmosphere_process<RRTMGPRadiation>);
        gm_factory.register_product("Physics Only",&physics::create_physics_only_grids_manager);

        // Create the grids manager
        auto& gm_params = ad_params.sublist("Grids Manager");
        const std::string& gm_type = gm_params.get<std::string>("Type");
        auto gm = GridsManagerFactory::instance().create(gm_type,atm_comm,gm_params);

        // Create the driver
        AtmosphereDriver ad;

        // Dummy timestamp
        util::TimeStamp time (0,0,0,0);

        // Initialize the driver
        ad.initialize(atm_comm, ad_params, time);

        /*
         * Setup the dummy problem and overwrite default initial conditions
         */

        // Get dimension sizes from the field manager
        const auto& grid = ad.get_grids_manager()->get_grid("Physics");
        const auto& field_mgr = *ad.get_field_mgr(grid->name());
        int ncol = grid->get_num_local_dofs();
        int nlay = grid->get_num_vertical_levels();

        // Get number of shortwave bands and number of gases from RRTMGP
        int nswbands = scream::rrtmgp::k_dist_sw.get_nband();
        int ngas     =   8;  // TODO: get this intelligently

        // Make sure we have the right dimension sizes
        REQUIRE(nlay == sw_flux_up_ref.dimension[1]-1);

        // Create yakl arrays to store the input data
        auto p_lay = real2d("p_lay", ncol, nlay);
        auto t_lay = real2d("t_lay", ncol, nlay);
        auto p_del = real2d("p_del", ncol, nlay);
        auto p_lev = real2d("p_lev", ncol, nlay+1);
        auto t_lev = real2d("t_lev", ncol, nlay+1);
        auto sfc_alb_dir = real2d("sfc_alb_dir", ncol, nswbands);
        auto sfc_alb_dif = real2d("sfc_alb_dif", ncol, nswbands);
        auto lwp = real2d("lwp", ncol, nlay);
        auto iwp = real2d("iwp", ncol, nlay);
        auto rel = real2d("rel", ncol, nlay);
        auto rei = real2d("rei", ncol, nlay);
        auto mu0 = real1d("mu0", ncol);
        auto gas_vmr = real3d("gas_vmr", ncol, nlay, ngas);

        // Need to calculate a dummy pseudo_density for our test problem
        parallel_for(Bounds<2>(nlay,ncol), YAKL_LAMBDA(int ilay, int icol) {
            p_del(icol,ilay) = abs(p_lev(icol,ilay+1) - p_lev(icol,ilay));
        });

        // Read in dummy Garand atmosphere; if this were an actual model simulation,
        // these would be passed as inputs to the driver
        // NOTE: set ncol to size of col_flx dimension in the input file. This is so
        // that we can compare to the reference data provided in that file. Note that
        // this will copy the first column of the input data (the first profile) ncol
        // times. We will then fill some fraction of these columns with clouds for
        // the test problem.
        GasConcs gas_concs;
        read_atmos(inputfile, p_lay, t_lay, p_lev, t_lev, gas_concs, ncol);

        // Setup dummy problem
        rrtmgpTest::dummy_atmos(
            inputfile, ncol, p_lay, t_lay,
            sfc_alb_dir, sfc_alb_dif, mu0,
            lwp, iwp, rel, rei
        );

        // Copy gases from gas_concs to gas_vmr array
        parallel_for(Bounds<3>(ncol,nlay,ngas), YAKL_LAMBDA(int icol, int ilay, int igas) {
            gas_vmr(icol,ilay,igas) = gas_concs.concs(icol,ilay,igas);
        });
        gas_concs.reset();

        // Before running, make a copy of T_mid so we can see changes
        auto T_mid0 = real2d("T_mid0", ncol, nlay);
        t_lay.deep_copy_to(T_mid0);

        // Grab views from field manager and copy in values from yakl arrays. Making
        // copies is necessary since the yakl::Array take in data arranged with ncol
        // as the fastest index, but the field manager expects the 2nd dimension as
        // the fastest index.
        auto d_pmid = field_mgr.get_field("p_mid").get_reshaped_view<Real**>();
        auto d_tmid = field_mgr.get_field("T_mid").get_reshaped_view<Real**>();
        auto d_pint = field_mgr.get_field("p_int").get_reshaped_view<Real**>();
        auto d_pdel = field_mgr.get_field("pseudo_density").get_reshaped_view<Real**>();
        auto d_tint = field_mgr.get_field("t_int").get_reshaped_view<Real**>();
        auto d_sfc_alb_dir = field_mgr.get_field("surf_alb_direct").get_reshaped_view<Real**>();
        auto d_sfc_alb_dif = field_mgr.get_field("surf_alb_diffuse").get_reshaped_view<Real**>();
        auto d_lwp = field_mgr.get_field("lwp").get_reshaped_view<Real**>();
        auto d_iwp = field_mgr.get_field("iwp").get_reshaped_view<Real**>();
        auto d_rel = field_mgr.get_field("eff_radius_qc").get_reshaped_view<Real**>();
        auto d_rei = field_mgr.get_field("eff_radius_qi").get_reshaped_view<Real**>();
        auto d_mu0 = field_mgr.get_field("cos_zenith").get_reshaped_view<Real*>();
        auto d_gas_vmr = field_mgr.get_field("gas_vmr").get_reshaped_view<Real***>();
        {
          const auto policy = ekat::ExeSpaceUtils<ExeSpace>::get_default_team_policy(ncol, nlay);
          Kokkos::parallel_for(policy, KOKKOS_LAMBDA(const MemberType& team) {
            const int i = team.league_rank();

            d_mu0(i) = mu0(i+1);
            Kokkos::parallel_for(Kokkos::TeamThreadRange(team, nlay), [&] (const int& k) {
              d_pmid(i,k) = p_lay(i+1,k+1);
              d_tmid(i,k) = t_lay(i+1,k+1);
              d_pdel(i,k) = p_del(i+1,k+1);
              d_lwp(i,k)  = lwp(i+1,k+1);
              d_iwp(i,k)  = iwp(i+1,k+1);
              d_rel(i,k)  = rel(i+1,k+1);
              d_rei(i,k)  = rei(i+1,k+1);
              d_pint(i,k) = p_lev(i+1,k+1);
              d_tint(i,k) = t_lev(i+1,k+1);

              Kokkos::parallel_for(Kokkos::ThreadVectorRange(team, ngas), [&] (const int& g) {
                d_gas_vmr(i,k,g) = gas_vmr(i+1,k+1,g+1);
              });
            });

            d_pint(i,nlay) = p_lev(i+1,nlay+1);
            d_tint(i,nlay) = t_lev(i+1,nlay+1);

            Kokkos::parallel_for(Kokkos::TeamThreadRange(team, nswbands), [&] (const int& k) {
              d_sfc_alb_dir(i,k) = sfc_alb_dir(i+1,k+1);
              d_sfc_alb_dif(i,k) = sfc_alb_dif(i+1,k+1);
            });
          });
        }
        Kokkos::fence();

        // Run driver
        ad.run(300.0);

        // Check values; The correct values have been stored in the field manager, we need to
        // copy back to YAKL::Array.
        auto d_sw_flux_up = field_mgr.get_field("sw_flux_up").get_reshaped_view<Real**>();
        auto d_sw_flux_dn = field_mgr.get_field("sw_flux_dn").get_reshaped_view<Real**>();
        auto d_sw_flux_dn_dir = field_mgr.get_field("sw_flux_dn_dir").get_reshaped_view<Real**>();
        auto d_lw_flux_up = field_mgr.get_field("lw_flux_up").get_reshaped_view<Real**>();
        auto d_lw_flux_dn = field_mgr.get_field("lw_flux_dn").get_reshaped_view<Real**>();
        auto sw_flux_up_test = real2d("sw_flux_up_test", ncol, nlay+1);
        auto sw_flux_dn_test = real2d("sw_flux_dn_test", ncol, nlay+1);
        auto sw_flux_dn_dir_test = real2d("sw_flux_dn_dir_test",  ncol, nlay+1);
        auto lw_flux_up_test = real2d("lw_flux_up_test", ncol, nlay+1);
        auto lw_flux_dn_test = real2d("lw_flux_dn_test", ncol, nlay+1);
        {
          const auto policy = ekat::ExeSpaceUtils<ExeSpace>::get_default_team_policy(ncol, nlay);
          Kokkos::parallel_for(policy, KOKKOS_LAMBDA(const MemberType& team) {
            const int i = team.league_rank();

            Kokkos::parallel_for(Kokkos::TeamThreadRange(team, nlay+1), [&] (const int& k) {
              if (k < nlay) t_lay(i+1,k+1) = d_tmid(i,k);

              sw_flux_up_test(i+1,k+1)     = d_sw_flux_up(i,k);
              sw_flux_dn_test(i+1,k+1)     = d_sw_flux_dn(i,k);
              sw_flux_dn_dir_test(i+1,k+1) = d_sw_flux_dn_dir(i,k);
              lw_flux_up_test(i+1,k+1)     = d_lw_flux_up(i,k);
              lw_flux_dn_test(i+1,k+1)     = d_lw_flux_dn(i,k);
            });
          });
        }
        Kokkos::fence();

        // Dumb check to verify that we did indeed update temperature
        REQUIRE(t_lay.createHostCopy()(1,1) != T_mid0.createHostCopy()(1,1));
        T_mid0.deallocate();

        // Make sure fluxes from field manager that were calculated in AD call of RRTMGP match reference fluxes from input file
        REQUIRE(rrtmgpTest::all_equals(sw_flux_up_ref    , sw_flux_up_test  ));
        REQUIRE(rrtmgpTest::all_equals(sw_flux_dn_ref    , sw_flux_dn_test    ));
        REQUIRE(rrtmgpTest::all_equals(sw_flux_dn_dir_ref, sw_flux_dn_dir_test));
        REQUIRE(rrtmgpTest::all_equals(lw_flux_up_ref    , lw_flux_up_test    ));
        REQUIRE(rrtmgpTest::all_equals(lw_flux_dn_ref    , lw_flux_dn_test    ));

        // Deallocate YAKL arrays
        p_lay.deallocate();
        t_lay.deallocate();
        p_del.deallocate();
        p_lev.deallocate();
        t_lev.deallocate();
        sfc_alb_dir.deallocate();
        sfc_alb_dif.deallocate();
        lwp.deallocate();
        iwp.deallocate();
        rel.deallocate();
        rei.deallocate();
        mu0.deallocate();
        gas_vmr.deallocate();
        sw_flux_up_test.deallocate();
        sw_flux_dn_test.deallocate();
        sw_flux_dn_dir_test.deallocate();
        lw_flux_up_test.deallocate();
        lw_flux_dn_test.deallocate();
        sw_flux_up_ref.deallocate();
        sw_flux_dn_ref.deallocate();
        sw_flux_dn_dir_ref.deallocate();
        lw_flux_up_ref.deallocate();
        lw_flux_dn_ref.deallocate();

        // Finalize the driver; needs to come before yakl::finalize because
        // rrtmgp::finalize() frees YAKL arrays
        ad.finalize();

        // Finalize YAKL
        yakl::finalize();

        // If we got this far, we were able to run the code through the AD
        REQUIRE(true);
    }
}
