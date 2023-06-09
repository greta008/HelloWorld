
! TODO: Add rules about ,value, reference scalars, and arrays in the interface


module cpp_interface_mod
  use params, only: crm_rknd, crm_iknd, crm_lknd
  use iso_c_binding
  implicit none

  interface

    subroutine crm(ncrms_in, pcols_in, dt_gl, plev, crm_input_bflxls, crm_input_wndls, crm_input_zmid, crm_input_zint, &
                   crm_input_pmid, crm_input_pint, crm_input_pdel, crm_input_ul, crm_input_vl, &
                   crm_input_tl, crm_input_qccl, crm_input_qiil, crm_input_ql, crm_input_tau00, &
                   crm_input_ul_esmt, crm_input_vl_esmt, &
                   crm_input_t_vt, crm_input_q_vt, crm_input_u_vt, &
                   crm_state_u_wind, crm_state_v_wind, crm_state_w_wind, crm_state_temperature, &
                   crm_state_qv, crm_state_qp, crm_state_qn, crm_rad_qrad, crm_rad_temperature, &
                   crm_rad_qv, crm_rad_qc, crm_rad_qi, crm_rad_cld, crm_output_subcycle_factor, &
                   crm_output_prectend, crm_output_precstend, crm_output_cld, crm_output_cldtop, &
                   crm_output_gicewp, crm_output_gliqwp, crm_output_mctot, crm_output_mcup, crm_output_mcdn, &
                   crm_output_mcuup, crm_output_mcudn, crm_output_qc_mean, crm_output_qi_mean, crm_output_qs_mean, &
                   crm_output_qg_mean, crm_output_qr_mean, crm_output_mu_crm, crm_output_md_crm, crm_output_eu_crm, &
                   crm_output_du_crm, crm_output_ed_crm, crm_output_flux_qt, crm_output_flux_u, crm_output_flux_v, &
                   crm_output_fluxsgs_qt, crm_output_tkez, crm_output_tkew, crm_output_tkesgsz, crm_output_tkz, crm_output_flux_qp, &
                   crm_output_precflux, crm_output_qt_trans, crm_output_qp_trans, crm_output_qp_fall, crm_output_qp_evp, &
                   crm_output_qp_src, crm_output_qt_ls, crm_output_t_ls, crm_output_jt_crm, crm_output_mx_crm, crm_output_cltot, &
                   crm_output_clhgh, crm_output_clmed, crm_output_cllow, &
                   crm_output_sltend, crm_output_qltend, crm_output_qcltend, crm_output_qiltend, &
                   crm_output_t_vt_tend, crm_output_q_vt_tend, crm_output_u_vt_tend, &
                   crm_output_t_vt_ls, crm_output_q_vt_ls, crm_output_u_vt_ls, &
                   crm_output_ultend, crm_output_vltend, &
                   crm_output_tk, crm_output_tkh, crm_output_qcl, crm_output_qci, crm_output_qpl, crm_output_qpi, &
                   crm_output_z0m, crm_output_taux, crm_output_tauy, crm_output_precc, crm_output_precl, crm_output_precsc, &
                   crm_output_precsl, crm_output_prec_crm,        & 
                   crm_clear_rh, &
                   lat0, long0, gcolp, igstep,  &
                   use_VT, VT_wn_max, use_ESMT, &
                   use_crm_accel, crm_accel_factor, crm_accel_uv) bind(C,name="crm")
      use params, only: crm_rknd, crm_iknd, crm_lknd
      use iso_c_binding, only: c_bool
      implicit none
      logical(c_bool), value :: use_VT
      integer(crm_iknd), value :: VT_wn_max
      logical(c_bool), value :: use_ESMT
      logical(c_bool), value :: use_crm_accel, crm_accel_uv
      integer(crm_iknd), value :: ncrms_in, pcols_in, plev, igstep
      real(crm_rknd), value :: dt_gl, crm_accel_factor
      integer(crm_iknd), dimension(*) :: gcolp
      real(crm_rknd), dimension(*) :: crm_input_bflxls, crm_input_wndls, crm_input_zmid, crm_input_zint, &
                                      crm_input_pmid, crm_input_pint, crm_input_pdel, crm_input_ul, crm_input_vl, &
                                      crm_input_tl, crm_input_qccl, crm_input_qiil, crm_input_ql, crm_input_tau00, &
                                      crm_input_ul_esmt, crm_input_vl_esmt, &
                                      crm_input_t_vt, crm_input_q_vt, &
                                      crm_state_u_wind, crm_state_v_wind, crm_state_w_wind, crm_state_temperature, &
                                      crm_state_qv, crm_state_qp, crm_state_qn, crm_rad_qrad, crm_rad_temperature, &
                                      crm_rad_qv, crm_rad_qc, crm_rad_qi, crm_rad_cld, crm_output_subcycle_factor, &
                                      crm_output_prectend, crm_output_precstend, crm_output_cld, crm_output_cldtop, &
                                      crm_output_gicewp, crm_output_gliqwp, crm_output_mctot, crm_output_mcup, crm_output_mcdn, &
                                      crm_output_mcuup, crm_output_mcudn, crm_output_qc_mean, crm_output_qi_mean, crm_output_qs_mean, &
                                      crm_output_qg_mean, crm_output_qr_mean, crm_output_mu_crm, crm_output_md_crm, crm_output_eu_crm, &
                                      crm_output_du_crm, crm_output_ed_crm, crm_output_flux_qt, crm_output_flux_u, crm_output_flux_v, &
                                      crm_output_fluxsgs_qt, crm_output_tkez, crm_output_tkew, crm_output_tkesgsz, crm_output_tkz, crm_output_flux_qp, &
                                      crm_output_precflux, crm_output_qt_trans, crm_output_qp_trans, crm_output_qp_fall, crm_output_qp_evp, &
                                      crm_output_qp_src, crm_output_qt_ls, crm_output_t_ls, crm_output_jt_crm, crm_output_mx_crm, crm_output_cltot, &
                                      crm_output_clhgh, crm_output_clmed, crm_output_cllow, &
                                      crm_output_sltend, crm_output_qltend, crm_output_qcltend, &
                                      crm_output_t_vt_tend, crm_output_q_vt_tend, crm_output_t_vt_ls, crm_output_q_vt_ls, &
                                      crm_input_u_vt, crm_output_u_vt_tend, crm_output_u_vt_ls, &
                                      crm_output_ultend, crm_output_vltend, &
                                      crm_output_qiltend, crm_output_tk, crm_output_tkh, crm_output_qcl, crm_output_qci, crm_output_qpl, crm_output_qpi, &
                                      crm_output_z0m, crm_output_taux, crm_output_tauy, crm_output_precc, crm_output_precl, crm_output_precsc, &
                                      crm_output_precsl, crm_output_prec_crm,        & 
                                      crm_clear_rh, lat0, long0
    end subroutine crm


    subroutine setparm() bind(C,name="setparm")
    end subroutine


  end interface

end module cpp_interface_mod
