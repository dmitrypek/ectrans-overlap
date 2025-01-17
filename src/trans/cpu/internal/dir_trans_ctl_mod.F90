! (C) Copyright 2001- ECMWF.
! (C) Copyright 2001- Meteo-France.
! 
! This software is licensed under the terms of the Apache Licence Version 2.0
! which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
! In applying this licence, ECMWF does not waive the privileges and immunities
! granted to it by virtue of its status as an intergovernmental organisation
! nor does it submit to any jurisdiction.
!

MODULE DIR_TRANS_CTL_MOD

USE PARKIND1,          ONLY: JPIM, JPRB
USE OVERLAP_TYPES_MOD, ONLY: BATCH
USE OVERLAP_TYPES_MOD, ONLY: BATCHLIST

IMPLICIT NONE

TYPE(BATCHLIST) :: ACTIVE_BATCHES
REAL(KIND=JPRB), ALLOCATABLE :: ZGTF(:,:)
INTEGER(KIND=JPIM), ALLOCATABLE :: NPTRFS(:)
INTEGER(KIND=JPIM), ALLOCATABLE :: IREQ_RECV(:,:)
REAL(KIND=JPRB), ALLOCATABLE :: ZCOMBUFR_HEAP(:,:,:)

CONTAINS
SUBROUTINE DIR_TRANS_CTL(KF_UV_G,KF_SCALARS_G,KF_GP,KF_FS,KF_UV,KF_SCALARS,&
 & PSPVOR,PSPDIV,PSPSCALAR,KVSETUV,KVSETSC,PGP,&
 & PSPSC3A,PSPSC3B,PSPSC2,KVSETSC3A,KVSETSC3B,KVSETSC2,PGPUV,PGP3A,PGP3B,PGP2)

!**** *DIR_TRANS_CTL* - Control routine for direct spectral transform.

!     Purpose.
!     --------
!        Control routine for the direct spectral transform

!**   Interface.
!     ----------
!     CALL DIR_TRANS_CTL(...)

!     Explicit arguments :
!     --------------------
!     KF_UV_G      - global number of spectral u-v fields
!     KF_SCALARS_G - global number of scalar spectral fields
!     KF_GP        - total number of output gridpoint fields
!     KF_FS        - total number of fields in fourier space
!     KF_UV        - local number of spectral u-v fields
!     KF_SCALARS   - local number of scalar spectral fields
!     PSPVOR(:,:)  - spectral vorticity
!     PSPDIV(:,:)  - spectral divergence
!     PSPSCALAR(:,:) - spectral scalarvalued fields
!     KVSETUV(:)  - indicating which 'b-set' in spectral space owns a
!                   vor/div field. Equivalant to NBSETLEV in the IFS.
!                   The length of KVSETUV should be the GLOBAL number
!                   of u/v fields which is the dimension of u and v releated
!                   fields in grid-point space.
!     KVESETSC(:) - indicating which 'b-set' in spectral space owns a
!                   scalar field. As for KVSETUV this argument is required
!                   if the total number of processors is greater than
!                   the number of processors used for distribution in
!                   spectral wave space.
!     PGP(:,:,:)  - gridpoint fields

!                  The ordering of the output fields is as follows (all
!                  parts are optional depending on the input switches):
!
!       u             : KF_UV_G fields
!       v             : KF_UV_G fields
!       scalar fields : KF_SCALARS_G fields

!     Method.
!     -------

!     Author.
!     -------
!        Mats Hamrud *ECMWF*

!     Modifications.
!     --------------
!        Original : 01-01-03

!     ------------------------------------------------------------------

USE TPM_GEN,         ONLY: NPROMATR, NOUT
USE ABORT_TRANS_MOD, ONLY: ABORT_TRANS
USE LINKED_LIST_M,   ONLY: LINKEDLISTNODE

IMPLICIT NONE

! Declaration of arguments

INTEGER(KIND=JPIM), INTENT(IN) :: KF_UV_G
INTEGER(KIND=JPIM), INTENT(IN) :: KF_SCALARS_G
INTEGER(KIND=JPIM), INTENT(IN) :: KF_GP
INTEGER(KIND=JPIM), INTENT(IN) :: KF_FS
INTEGER(KIND=JPIM), INTENT(IN) :: KF_UV
INTEGER(KIND=JPIM), INTENT(IN) :: KF_SCALARS
REAL(KIND=JPRB)    ,OPTIONAL, INTENT(OUT) :: PSPVOR(:,:)
REAL(KIND=JPRB)    ,OPTIONAL, INTENT(OUT) :: PSPDIV(:,:)
REAL(KIND=JPRB)    ,OPTIONAL, INTENT(OUT) :: PSPSCALAR(:,:)
REAL(KIND=JPRB)    ,OPTIONAL, INTENT(OUT) :: PSPSC3A(:,:,:)
REAL(KIND=JPRB)    ,OPTIONAL, INTENT(OUT) :: PSPSC3B(:,:,:)
REAL(KIND=JPRB)    ,OPTIONAL, INTENT(OUT) :: PSPSC2(:,:)
INTEGER(KIND=JPIM) ,OPTIONAL, INTENT(IN)  :: KVSETUV(:)
INTEGER(KIND=JPIM) ,OPTIONAL, INTENT(IN)  :: KVSETSC(:)
INTEGER(KIND=JPIM) ,OPTIONAL, INTENT(IN)  :: KVSETSC3A(:)
INTEGER(KIND=JPIM) ,OPTIONAL, INTENT(IN)  :: KVSETSC3B(:)
INTEGER(KIND=JPIM) ,OPTIONAL, INTENT(IN)  :: KVSETSC2(:)
REAL(KIND=JPRB)    ,OPTIONAL, INTENT(IN)  :: PGP(:,:,:)
REAL(KIND=JPRB)    ,OPTIONAL, INTENT(IN)  :: PGPUV(:,:,:,:)
REAL(KIND=JPRB)    ,OPTIONAL, INTENT(IN)  :: PGP3A(:,:,:,:)
REAL(KIND=JPRB)    ,OPTIONAL, INTENT(IN)  :: PGP3B(:,:,:,:)
REAL(KIND=JPRB)    ,OPTIONAL, INTENT(IN)  :: PGP2(:,:,:)

TYPE(BATCH) :: NEW_BATCH
INTEGER(KIND=JPIM) :: IBLKS,JBLK
INTEGER(KIND=JPIM) :: NDONE
TYPE(LINKEDLISTNODE), POINTER :: IB

!     ------------------------------------------------------------------

! Perform transform

WRITE(NOUT,*) "KF_UV_G = ", KF_UV_G
WRITE(NOUT,*) "KF_SCALARS_G = ", KF_SCALARS_G
WRITE(NOUT,*) "KF_GP = ", KF_GP
WRITE(NOUT,*) "KF_FS = ", KF_FS
WRITE(NOUT,*) "KF_UV = ", KF_UV
WRITE(NOUT,*) "KF_SCALARS = ", KF_SCALARS

IF (NPROMATR > 0 .AND. KF_GP > NPROMATR) THEN

  IBLKS = (KF_GP - 1) / NPROMATR + 1

  JBLK = 1
  NDONE = 0

  CALL INIT_MOD(KF_FS,IBLKS)
  
  CALL ACTIVATE(JBLK, KF_GP, KF_SCALARS_G, KF_UV_G, KVSETUV, KVSETSC, PGP)

  DO WHILE (NDONE < IBLKS)

    IB => ACTIVE_BATCHES%HEAD
    DO WHILE (ASSOCIATED(IB))
      SELECT TYPE (THISBATCH => IB%VALUE)
      TYPE IS (BATCH)
        IF (THISBATCH%COMM_COMPLETE()) THEN
          CALL THISBATCH%FINISH_COMM(PSPVOR, PSPDIV, PSPSCALAR)
          NDONE = NDONE + 1
          EXIT
        END IF
          IB => IB%NEXT
      END SELECT
    END DO

    IF (JBLK < IBLKS) THEN
      JBLK = JBLK + 1
      CALL ACTIVATE(JBLK, KF_GP, KF_SCALARS_G, KF_UV_G, KVSETUV, KVSETSC, PGP)
    ENDIF
  ENDDO
ELSE

  ! No splitting of fields, transform done in one go
  CALL ABORT_TRANS("DIR_TRANS_CTL: NPROMATR = 0 feature disabled for overlap version")

ENDIF

!     ------------------------------------------------------------------

END SUBROUTINE DIR_TRANS_CTL

SUBROUTINE INIT_MOD(KF_FS,IBLKS)

  IMPLICIT NONE
  INTEGER, INTENT(IN) :: KF_FS,IBLKS

  ALLOCATE(ZGTF(KF_FS,D%NLENGTF))
! Now, force the OS to allocate this shared array right now, not when it starts
! to be used which is an OPEN-MP loop, that would cause a threads
! synchronization lock :
  IF (KF_FS > 0 .AND. D%NLENGTF > 0) THEN
     ZGTF(1,1)=HUGE(1._JPRB)
  ENDIF
  
  ALLOCATE(NPTRFS(IBLKS+1))
! Need to compute knrecv and krecvcount !!!!!
  ALLOCATE(IREQ_RECV(KNRECV,IBLKS)
  ALLOCATE(ZCOMBUFR_HEAP(-1:KRECVCOUNT,KNRECV,IBLKS))

END SUBROUTINE INIT_MOD

SUBROUTINE ACTIVATE(N, KF_GP, KF_SCALARS_G, KF_UV_G, KVSETUV, KVSETSC, PGP)
  INTEGER, INTENT(IN)                         :: N
  INTEGER(KIND=JPIM), INTENT(IN)              :: KF_GP
  INTEGER(KIND=JPIM), INTENT(IN)              :: KF_SCALARS_G
  INTEGER(KIND=JPIM), INTENT(IN)              :: KF_UV_G
  INTEGER(KIND=JPIM), OPTIONAL, INTENT(IN)    :: KVSETUV(:)
  INTEGER(KIND=JPIM), OPTIONAL, INTENT(IN)    :: KVSETSC(:)
  REAL(KIND=JPRB),    OPTIONAL, INTENT(IN)    :: PGP(:,:,:)

  CLASS(BATCH), POINTER :: NEW_BATCH

  ! Add a new Batch to the list
  CALL ACTIVE_BATCHES%APPEND(BATCH(N, KF_GP, KF_SCALARS_G, KF_UV_G, KVSETUV, KVSETSC))

  SELECT TYPE (NEW_BATCH => ACTIVE_BATCHES%TAIL%VALUE)
  TYPE IS (BATCH)
    CALL NEW_BATCH%START_COMM(PGP)
  END SELECT
END SUBROUTINE ACTIVATE

END MODULE DIR_TRANS_CTL_MOD
