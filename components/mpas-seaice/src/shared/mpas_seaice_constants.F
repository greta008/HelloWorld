!|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
!
!  seaice_constants
!
!> \brief
!> \author Adrian K. Turner, LANL
!> \date 2013-2014
!> \details
!>
!
!-----------------------------------------------------------------------

module seaice_constants

  use mpas_derived_types

  use ice_constants_colpkg, only: &
       gravit, &
       rhoi, &
       rhos, &
       rhow, &
       puny, &
       stefan_boltzmann, &
       emissivity, &
       Tffresh, &
       cp_air, &
       cp_ocn, &
       Lsub, &
       Lvap, &
       Lfresh, &
       Pstar, &
       Cstar, &
       dragio, &
       albocn, &
       rhofresh, &
       vonkar, &
       iceruf, &
       zref, &
       ice_ref_salinity, &
       sk_l, &
       R_gC2molC

  private
  save

  ! fundamental constants
  real (kind=RKIND), parameter, public :: &
       pii = 3.141592653589793_RKIND, &
       seaiceDegreesToRadians = pii / 180.0_RKIND, &
       seaiceRadiansToDegrees = 180.0_RKIND / pii, &
       seaiceSecondsPerYear = 24.0_RKIND * 3600.0_RKIND * 365.0_RKIND, &
       seaiceSecondsPerDay  = 24.0_RKIND * 3600.0_RKIND, &
       seaiceDaysPerSecond = 1.0_RKIND/seaiceSecondsPerDay

  ! Earth constants
  real (kind=RKIND), parameter, public :: &
       seaiceGravity = gravit, &    ! gravitational acceleration (m/s^2)
       omega         = 7.29212e-5_RKIND   ! angular rotation rate of the Earth [s-1]

  character (len=*), public, parameter :: &
       coupleAlarmID = 'coupling'

  real(kind=RKIND), parameter, public :: &
       seaicePuny = puny

  ! physical constants
  real(kind=RKIND), parameter, public :: &
       seaiceDensityIce        = rhoi, & ! density of ice (kg/m^3)
       seaiceDensitySnow       = rhos, & ! density of snow (kg/m^3)
       seaiceDensitySeaWater   = rhow, & ! density of seawater (kg/m^3)
       seaiceDensityFreshwater = rhofresh ! density of freshwater (kg/m^3)

  ! thermodynamic constants
  real(kind=RKIND), parameter, public :: &
       seaiceStefanBoltzmann          = stefan_boltzmann, & ! J m-2 K-4 s-1
       seaiceIceSnowEmissivity        = emissivity, &       ! emissivity of snow and ice
       seaiceFreshWaterFreezingPoint  = Tffresh, &          ! freezing temp of fresh ice (K)
       seaiceAirSpecificHeat          = cp_air, &           ! specific heat of air (J/kg/K)
       seaiceSeaWaterSpecificHeat     = cp_ocn, &           ! specific heat of ocn (J/kg/K)
       seaiceLatentHeatSublimation    = Lsub, &             ! latent heat, sublimation freshwater (J/kg)
       seaiceLatentHeatVaporization   = Lvap, &             ! latent heat, vaporization freshwater (J/kg)
       seaiceLatentHeatMelting        = Lfresh, &           ! latent heat of melting of fresh ice (J/kg)
       seaiceOceanAlbedo              = albocn, &           ! Ocean albedo
       seaiceVonKarmanConstant        = vonkar, &           ! Von Karman constant
       seaiceIceSurfaceRoughness      = iceruf, &           ! ice surface roughness (m)
       seaiceStabilityReferenceHeight = zref, &             ! stability reference height (m)
       seaiceReferenceSalinity        = ice_ref_salinity    ! ice reference salinity (ppt)

  ! dynamics constants
  real(kind=RKIND), parameter, public :: &
       seaiceIceStrengthConstantHiblerP = Pstar, & ! P* constant in Hibler strength formulation
       seaiceIceStrengthConstantHiblerC = Cstar, & ! C* constant in Hibler strength formulation
       seaiceIceOceanDragCoefficient    = dragio   ! ice ocean drag coefficient

  ! minimum sea ice area
  real(kind=RKIND), parameter, public :: &
       iceAreaMinimum       = seaicePuny, &
       iceThicknessMinimum  = seaicePuny, &
       snowThicknessMinimum = seaicePuny

   ! biogeochemistry constants
   real(kind=RKIND), parameter, public :: &
        skeletalLayerThickness = sk_l      , &
        gramsCarbonPerMolCarbon = R_gC2molC    ! g carbon per mol carbon


end module seaice_constants
