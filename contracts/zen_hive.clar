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
(define-constant err-contract-paused (err u108))
(define-constant err-rate-limit (err u109))

;; Configuration
(define-constant minimum-stake u1000)
(define-constant governance-threshold u100000)
(define-constant unstake-timelock u144) ;; 24 hours in blocks
(define-constant emergency-unstake-penalty u200) ;; 20% penalty
(define-constant staking-apr u100) ;; 10% APR

;; Data Variables
(define-data-var challenge-counter uint u0)
(define-data-var total-staked uint u0)
(define-data-var proposal-counter uint u0)
(define-data-var contract-paused bool false)
(define-data-var last-action-height uint u0)

;; Define token
(define-fungible-token zen-token)

;; Enhanced Data Maps
(define-map user-stakes
    principal
    {
        amount: uint,
        locked-until: uint,
        delegated-to: (optional principal),
        rewards-accumulated: uint,
        last-reward-calculation: uint
    })

;; Rate Limiting
(define-private (check-rate-limit)
    (let ((blocks-since-last (- block-height (var-get last-action-height))))
        (asserts! (> blocks-since-last u10) err-rate-limit)
        (var-set last-action-height block-height)
        (ok true)))

;; Reward Calculation
(define-private (calculate-rewards (stake-info (tuple (amount uint) (last-reward-calculation uint))))
    (let (
        (blocks-staked (- block-height (get last-reward-calculation stake-info)))
        (amount-staked (get amount stake-info))
        (reward-rate (/ (* staking-apr amount-staked) (* u365 u144)))
        (new-rewards (* blocks-staked reward-rate))
    )
        new-rewards))

;; Enhanced Staking Functions
(define-public (stake-tokens (amount uint))
    (begin
        (asserts! (not (var-get contract-paused)) err-contract-paused)
        (try! (check-rate-limit))
        (let (
            (current-stake (default-to 
                { amount: u0, locked-until: u0, delegated-to: none, rewards-accumulated: u0, last-reward-calculation: block-height } 
                (map-get? user-stakes tx-sender)))
        )
            (asserts! (> amount u0) err-invalid-amount)
            (try! (ft-transfer? zen-token amount tx-sender (as-contract tx-sender)))
            (map-set user-stakes tx-sender 
                (merge current-stake 
                    { 
                        amount: (+ (get amount current-stake) amount),
                        locked-until: (+ block-height unstake-timelock),
                        last-reward-calculation: block-height
                    }))
            (var-set total-staked (+ (var-get total-staked) amount))
            (try! (emit-event "STAKE" (concat (to-ascii amount) " tokens staked")))
            (ok true))))

;; New Emergency Unstake
(define-public (emergency-unstake (amount uint))
    (begin
        (asserts! (not (var-get contract-paused)) err-contract-paused)
        (let (
            (current-stake (unwrap! (map-get? user-stakes tx-sender) err-not-found))
            (penalty (/ (* amount emergency-unstake-penalty) u1000))
        )
            (asserts! (>= (get amount current-stake) amount) err-insufficient-stake)
            (try! (as-contract (ft-transfer? zen-token (- amount penalty) tx-sender tx-sender)))
            (map-set user-stakes tx-sender 
                (merge current-stake 
                    { amount: (- (get amount current-stake) amount) }))
            (var-set total-staked (- (var-get total-staked) amount))
            (try! (emit-event "EMERGENCY_UNSTAKE" 
                (concat (to-ascii amount) " tokens unstaked with penalty")))
            (ok true))))

;; Admin Functions
(define-public (pause-contract)
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (var-set contract-paused true)
        (try! (emit-event "CONTRACT_PAUSED" "Contract paused by admin"))
        (ok true)))

(define-public (unpause-contract)
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (var-set contract-paused false)
        (try! (emit-event "CONTRACT_UNPAUSED" "Contract unpaused by admin"))
        (ok true)))
