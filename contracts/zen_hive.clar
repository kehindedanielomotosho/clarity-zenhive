;; ZenHive - Mindfulness Challenge Platform

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-not-active (err u103))
(define-constant err-insufficient-stake (err u104))
(define-constant err-timelock-active (err u105))
(define-constant err-invalid-amount (err u106))
(define-constant err-proposal-executed (err u107))

(define-constant minimum-stake u1000)
(define-constant governance-threshold u100000)
(define-constant unstake-timelock u144) ;; 24 hours in blocks

;; Data Variables
(define-data-var challenge-counter uint u0)
(define-data-var total-staked uint u0)
(define-data-var proposal-counter uint u0)

;; Define token
(define-fungible-token zen-token)

;; Data Maps
(define-map challenges uint 
    {
        creator: principal,
        title: (string-ascii 100),
        description: (string-ascii 500),
        start-time: uint,
        end-time: uint,
        reward: uint,
        active: bool
    })

(define-map user-stakes
    principal
    {
        amount: uint,
        locked-until: uint,
        delegated-to: (optional principal)
    })

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
        executed: bool,
        snapshot-block: uint
    })

;; Events
(define-data-var last-event-id uint u0)

(define-map events 
    uint 
    {
        event-type: (string-ascii 20),
        data: (string-ascii 256)
    })

;; Helper Functions
(define-private (emit-event (event-type (string-ascii 20)) (data (string-ascii 256)))
    (let ((event-id (var-get last-event-id)))
        (map-set events event-id 
            {
                event-type: event-type,
                data: data
            })
        (var-set last-event-id (+ event-id u1))
        (ok true)))

;; Staking Functions
(define-public (stake-tokens (amount uint))
    (let (
        (current-stake (default-to 
            { amount: u0, locked-until: u0, delegated-to: none } 
            (map-get? user-stakes tx-sender)))
    )
        (asserts! (> amount u0) err-invalid-amount)
        (try! (ft-transfer? zen-token amount tx-sender (as-contract tx-sender)))
        (map-set user-stakes tx-sender 
            (merge current-stake 
                { 
                    amount: (+ (get amount current-stake) amount),
                    locked-until: (+ block-height unstake-timelock)
                }))
        (var-set total-staked (+ (var-get total-staked) amount))
        (try! (emit-event "STAKE" (concat (to-ascii amount) " tokens staked")))
        (ok true)))

(define-public (unstake-tokens (amount uint))
    (let (
        (current-stake (unwrap! (map-get? user-stakes tx-sender) err-not-found))
        (locked-until (get locked-until current-stake))
    )
        (asserts! (>= (get amount current-stake) amount) err-insufficient-stake)
        (asserts! (>= block-height locked-until) err-timelock-active)
        (try! (as-contract (ft-transfer? zen-token amount tx-sender tx-sender)))
        (map-set user-stakes tx-sender 
            (merge current-stake 
                { amount: (- (get amount current-stake) amount) }))
        (var-set total-staked (- (var-get total-staked) amount))
        (try! (emit-event "UNSTAKE" (concat (to-ascii amount) " tokens unstaked")))
        (ok true)))

;; Delegation Functions
(define-public (delegate-votes (delegate-to principal))
    (let ((current-stake (unwrap! (map-get? user-stakes tx-sender) err-not-found)))
        (map-set user-stakes tx-sender 
            (merge current-stake { delegated-to: (some delegate-to) }))
        (try! (emit-event "DELEGATE" (concat "Delegated to " (to-ascii delegate-to))))
        (ok true)))

;; Governance Functions
[... remaining governance functions with similar improvements ...]
