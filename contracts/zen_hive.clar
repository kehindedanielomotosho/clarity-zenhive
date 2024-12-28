;; ZenHive - Mindfulness Challenge Platform

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-not-active (err u103))

;; Data Variables
(define-data-var challenge-counter uint u0)

;; Define token
(define-fungible-token zen-token)

;; Data Maps
(define-map challenges
    uint 
    {
        creator: principal,
        title: (string-ascii 100),
        description: (string-ascii 500),
        start-time: uint,
        end-time: uint,
        reward: uint,
        active: bool
    }
)

(define-map challenge-participants 
    { challenge-id: uint, participant: principal }
    { completed: bool, reflection: (optional (string-ascii 1000)) }
)

(define-map user-profiles
    principal
    {
        total-participations: uint,
        tokens-earned: uint
    }
)

;; Public Functions

;; Create a new challenge
(define-public (create-challenge (title (string-ascii 100)) (description (string-ascii 500)) (start-time uint) (end-time uint) (reward uint))
    (let ((challenge-id (var-get challenge-counter)))
        (if (is-eq tx-sender contract-owner)
            (begin
                (map-set challenges challenge-id {
                    creator: tx-sender,
                    title: title,
                    description: description,
                    start-time: start-time,
                    end-time: end-time,
                    reward: reward,
                    active: true
                })
                (var-set challenge-counter (+ challenge-id u1))
                (ok challenge-id)
            )
            err-owner-only
        )
    )
)

;; Join a challenge
(define-public (join-challenge (challenge-id uint))
    (let ((challenge (unwrap! (map-get? challenges challenge-id) err-not-found)))
        (if (get active challenge)
            (begin
                (map-set challenge-participants 
                    { challenge-id: challenge-id, participant: tx-sender }
                    { completed: false, reflection: none }
                )
                (ok true)
            )
            err-not-active
        )
    )
)

;; Submit reflection and complete challenge
(define-public (complete-challenge (challenge-id uint) (reflection (string-ascii 1000)))
    (let (
        (challenge (unwrap! (map-get? challenges challenge-id) err-not-found))
        (participant-info (unwrap! (map-get? challenge-participants { challenge-id: challenge-id, participant: tx-sender }) err-not-found))
    )
        (if (get active challenge)
            (begin
                (map-set challenge-participants 
                    { challenge-id: challenge-id, participant: tx-sender }
                    { completed: true, reflection: (some reflection) }
                )
                (try! (ft-mint? zen-token (get reward challenge) tx-sender))
                (ok true)
            )
            err-not-active
        )
    )
)

;; Read-only functions

(define-read-only (get-challenge (challenge-id uint))
    (ok (map-get? challenges challenge-id))
)

(define-read-only (get-participant-info (challenge-id uint) (participant principal))
    (ok (map-get? challenge-participants { challenge-id: challenge-id, participant: participant }))
)

(define-read-only (get-user-profile (user principal))
    (ok (map-get? user-profiles user))
)