;; ZenHive - Mindfulness Challenge Platform

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-not-active (err u103))
(define-constant err-insufficient-stake (err u104))
(define-constant minimum-stake u1000)
(define-constant governance-threshold u100000)

;; Data Variables
(define-data-var challenge-counter uint u0)
(define-data-var total-staked uint u0)
(define-data-var proposal-counter uint u0)

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
        tokens-earned: uint,
        staked-amount: uint
    }
)

(define-map governance-proposals
    uint
    {
        proposer: principal,
        title: (string-ascii 100),
        description: (string-ascii 1000),
        start-block: uint,
        end-block: uint,
        yes-votes: uint,
        no-votes: uint,
        executed: bool
    }
)

(define-map votes
    { proposal-id: uint, voter: principal }
    { amount: uint, vote: bool }
)

;; Staking Functions
(define-public (stake-tokens (amount uint))
    (let (
        (user-profile (default-to { total-participations: u0, tokens-earned: u0, staked-amount: u0 } 
            (map-get? user-profiles tx-sender)))
    )
        (try! (ft-transfer? zen-token amount tx-sender (as-contract tx-sender)))
        (map-set user-profiles tx-sender 
            (merge user-profile { staked-amount: (+ (get staked-amount user-profile) amount) }))
        (var-set total-staked (+ (var-get total-staked) amount))
        (ok true)
    )
)

(define-public (unstake-tokens (amount uint))
    (let (
        (user-profile (unwrap! (map-get? user-profiles tx-sender) err-not-found))
        (staked (get staked-amount user-profile))
    )
        (asserts! (>= staked amount) err-insufficient-stake)
        (try! (as-contract (ft-transfer? zen-token amount tx-sender tx-sender)))
        (map-set user-profiles tx-sender 
            (merge user-profile { staked-amount: (- staked amount) }))
        (var-set total-staked (- (var-get total-staked) amount))
        (ok true)
    )
)

;; Governance Functions
(define-public (create-proposal (title (string-ascii 100)) (description (string-ascii 1000)) (duration uint))
    (let (
        (user-profile (unwrap! (map-get? user-profiles tx-sender) err-not-found))
        (proposal-id (var-get proposal-counter))
    )
        (asserts! (>= (get staked-amount user-profile) governance-threshold) err-insufficient-stake)
        (map-set governance-proposals proposal-id {
            proposer: tx-sender,
            title: title,
            description: description,
            start-block: block-height,
            end-block: (+ block-height duration),
            yes-votes: u0,
            no-votes: u0,
            executed: false
        })
        (var-set proposal-counter (+ proposal-id u1))
        (ok proposal-id)
    )
)

(define-public (vote-on-proposal (proposal-id uint) (vote bool))
    (let (
        (proposal (unwrap! (map-get? governance-proposals proposal-id) err-not-found))
        (user-profile (unwrap! (map-get? user-profiles tx-sender) err-not-found))
        (stake (get staked-amount user-profile))
    )
        (asserts! (>= stake minimum-stake) err-insufficient-stake)
        (asserts! (< block-height (get end-block proposal)) err-not-active)
        (map-set votes { proposal-id: proposal-id, voter: tx-sender } { amount: stake, vote: vote })
        (map-set governance-proposals proposal-id
            (merge proposal {
                yes-votes: (if vote (+ (get yes-votes proposal) stake) (get yes-votes proposal)),
                no-votes: (if vote (get no-votes proposal) (+ (get no-votes proposal) stake))
            })
        )
        (ok true)
    )
)

;; Original Functions
[... rest of original contract functions ...]
