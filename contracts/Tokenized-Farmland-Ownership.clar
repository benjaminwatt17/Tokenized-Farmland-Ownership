(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INVALID_AMOUNT (err u101))
(define-constant ERR_INSUFFICIENT_BALANCE (err u102))
(define-constant ERR_LAND_NOT_FOUND (err u103))
(define-constant ERR_ALREADY_EXISTS (err u104))
(define-constant ERR_INVALID_PERCENTAGE (err u105))
(define-constant ERR_NO_PROFITS (err u106))
(define-constant ERR_TRANSFER_FAILED (err u107))

(define-constant ERR_MILESTONE_NOT_REACHED (err u108))
(define-constant ERR_INVALID_MILESTONE (err u109))
(define-constant ERR_SEASON_COMPLETE (err u110))

(define-constant MILESTONE_PLANTED u1)
(define-constant MILESTONE_GROWING u2)
(define-constant MILESTONE_HARVESTED u3)

(define-fungible-token farmland-token)

(define-map land-parcels
  { land-id: uint }
  {
    owner: principal,
    location: (string-ascii 100),
    size-acres: uint,
    total-tokens: uint,
    tokens-sold: uint,
    price-per-token: uint,
    active: bool,
    total-profits: uint,
    last-profit-distribution: uint
  }
)

(define-map investor-holdings
  { investor: principal, land-id: uint }
  { tokens-held: uint, last-claim-block: uint }
)

(define-map land-counter
  { counter: (string-ascii 10) }
  { value: uint }
)

(define-data-var next-land-id uint u1)

(define-public (create-land-parcel (location (string-ascii 100)) (size-acres uint) (total-tokens uint) (price-per-token uint))
  (let
    (
      (land-id (var-get next-land-id))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (> total-tokens u0) ERR_INVALID_AMOUNT)
    (asserts! (> price-per-token u0) ERR_INVALID_AMOUNT)
    (asserts! (> size-acres u0) ERR_INVALID_AMOUNT)
    
    (map-set land-parcels
      { land-id: land-id }
      {
        owner: tx-sender,
        location: location,
        size-acres: size-acres,
        total-tokens: total-tokens,
        tokens-sold: u0,
        price-per-token: price-per-token,
        active: true,
        total-profits: u0,
        last-profit-distribution: stacks-block-height
      }
    )
    
    (var-set next-land-id (+ land-id u1))
    (ok land-id)
  )
)

(define-public (purchase-tokens (land-id uint) (token-amount uint))
  (let
    (
      (land-data (unwrap! (map-get? land-parcels { land-id: land-id }) ERR_LAND_NOT_FOUND))
      (total-cost (* token-amount (get price-per-token land-data)))
      (current-holding (default-to { tokens-held: u0, last-claim-block: stacks-block-height } 
                                  (map-get? investor-holdings { investor: tx-sender, land-id: land-id })))
    )
    (asserts! (get active land-data) ERR_LAND_NOT_FOUND)
    (asserts! (> token-amount u0) ERR_INVALID_AMOUNT)
    (asserts! (<= (+ (get tokens-sold land-data) token-amount) (get total-tokens land-data)) ERR_INSUFFICIENT_BALANCE)
    
    (try! (stx-transfer? total-cost tx-sender (get owner land-data)))
    
    (try! (ft-mint? farmland-token token-amount tx-sender))
    
    (map-set land-parcels
      { land-id: land-id }
      (merge land-data { tokens-sold: (+ (get tokens-sold land-data) token-amount) })
    )
    
    (map-set investor-holdings
      { investor: tx-sender, land-id: land-id }
      { 
        tokens-held: (+ (get tokens-held current-holding) token-amount),
        last-claim-block: (get last-claim-block current-holding)
      }
    )
    
    (ok token-amount)
  )
)

(define-public (transfer-tokens (recipient principal) (land-id uint) (token-amount uint))
  (let
    (
      (sender-holding (unwrap! (map-get? investor-holdings { investor: tx-sender, land-id: land-id }) ERR_INSUFFICIENT_BALANCE))
      (recipient-holding (default-to { tokens-held: u0, last-claim-block: stacks-block-height }
                                    (map-get? investor-holdings { investor: recipient, land-id: land-id })))
    )
    (asserts! (>= (get tokens-held sender-holding) token-amount) ERR_INSUFFICIENT_BALANCE)
    (asserts! (> token-amount u0) ERR_INVALID_AMOUNT)
    
    (try! (ft-transfer? farmland-token token-amount tx-sender recipient))
    
    (map-set investor-holdings
      { investor: tx-sender, land-id: land-id }
      (merge sender-holding { tokens-held: (- (get tokens-held sender-holding) token-amount) })
    )
    
    (map-set investor-holdings
      { investor: recipient, land-id: land-id }
      (merge recipient-holding { tokens-held: (+ (get tokens-held recipient-holding) token-amount) })
    )
    
    (ok true)
  )
)

(define-public (distribute-profits (land-id uint) (total-profit uint))
  (let
    (
      (land-data (unwrap! (map-get? land-parcels { land-id: land-id }) ERR_LAND_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get owner land-data)) ERR_UNAUTHORIZED)
    (asserts! (> total-profit u0) ERR_INVALID_AMOUNT)
    (asserts! (get active land-data) ERR_LAND_NOT_FOUND)
    
    (map-set land-parcels
      { land-id: land-id }
      (merge land-data { 
        total-profits: (+ (get total-profits land-data) total-profit),
        last-profit-distribution: stacks-block-height
      })
    )
    
    (ok total-profit)
  )
)

(define-public (claim-profits (land-id uint))
  (let
    (
      (land-data (unwrap! (map-get? land-parcels { land-id: land-id }) ERR_LAND_NOT_FOUND))
      (investor-data (unwrap! (map-get? investor-holdings { investor: tx-sender, land-id: land-id }) ERR_INSUFFICIENT_BALANCE))
      (ownership-percentage (/ (* (get tokens-held investor-data) u10000) (get total-tokens land-data)))
      (claimable-profit (/ (* (get total-profits land-data) ownership-percentage) u10000))
    )
    (asserts! (> (get tokens-held investor-data) u0) ERR_INSUFFICIENT_BALANCE)
    (asserts! (> claimable-profit u0) ERR_NO_PROFITS)
    (asserts! (> (get last-profit-distribution land-data) (get last-claim-block investor-data)) ERR_NO_PROFITS)
    
    (try! (as-contract (stx-transfer? claimable-profit tx-sender tx-sender)))
    
    (map-set investor-holdings
      { investor: tx-sender, land-id: land-id }
      (merge investor-data { last-claim-block: stacks-block-height })
    )
    
    (ok claimable-profit)
  )
)

(define-public (deactivate-land (land-id uint))
  (let
    (
      (land-data (unwrap! (map-get? land-parcels { land-id: land-id }) ERR_LAND_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get owner land-data)) ERR_UNAUTHORIZED)
    
    (map-set land-parcels
      { land-id: land-id }
      (merge land-data { active: false })
    )
    
    (ok true)
  )
)

(define-read-only (get-land-info (land-id uint))
  (map-get? land-parcels { land-id: land-id })
)

(define-read-only (get-investor-holding (investor principal) (land-id uint))
  (map-get? investor-holdings { investor: investor, land-id: land-id })
)

(define-read-only (get-token-balance (account principal))
  (ft-get-balance farmland-token account)
)

(define-read-only (calculate-ownership-percentage (investor principal) (land-id uint))
  (let
    (
      (land-data (unwrap! (map-get? land-parcels { land-id: land-id }) ERR_LAND_NOT_FOUND))
      (investor-data (unwrap! (map-get? investor-holdings { investor: investor, land-id: land-id }) ERR_INSUFFICIENT_BALANCE))
    )
    (ok (/ (* (get tokens-held investor-data) u10000) (get total-tokens land-data)))
  )
)

(define-read-only (calculate-claimable-profits (investor principal) (land-id uint))
  (let
    (
      (land-data (unwrap! (map-get? land-parcels { land-id: land-id }) ERR_LAND_NOT_FOUND))
      (investor-data (unwrap! (map-get? investor-holdings { investor: investor, land-id: land-id }) ERR_INSUFFICIENT_BALANCE))
      (ownership-percentage (/ (* (get tokens-held investor-data) u10000) (get total-tokens land-data)))
    )
    (ok (/ (* (get total-profits land-data) ownership-percentage) u10000))
  )
)

(define-read-only (get-total-supply)
  (ft-get-supply farmland-token)
)

(define-map land-valuations
  { land-id: uint }
  { 
    current-value-per-acre: uint,
    last-updated: uint,
    total-market-value: uint,
    valuation-count: uint
  }
)

(define-map valuation-history
  { land-id: uint, valuation-index: uint }
  {
    value-per-acre: uint,
    timestamp: uint,
    total-value: uint
  }
)

(define-public (update-land-valuation (land-id uint) (new-value-per-acre uint))
  (let
    (
      (land-data (unwrap! (map-get? land-parcels { land-id: land-id }) ERR_LAND_NOT_FOUND))
      (current-valuation (default-to 
        { current-value-per-acre: u0, last-updated: u0, total-market-value: u0, valuation-count: u0 }
        (map-get? land-valuations { land-id: land-id })))
      (new-total-value (* new-value-per-acre (get size-acres land-data)))
      (new-valuation-count (+ (get valuation-count current-valuation) u1))
    )
    (asserts! (is-eq tx-sender (get owner land-data)) ERR_UNAUTHORIZED)
    (asserts! (> new-value-per-acre u0) ERR_INVALID_AMOUNT)
    (asserts! (get active land-data) ERR_LAND_NOT_FOUND)
    
    (map-set valuation-history
      { land-id: land-id, valuation-index: new-valuation-count }
      {
        value-per-acre: new-value-per-acre,
        timestamp: stacks-block-height,
        total-value: new-total-value
      }
    )
    
    (map-set land-valuations
      { land-id: land-id }
      {
        current-value-per-acre: new-value-per-acre,
        last-updated: stacks-block-height,
        total-market-value: new-total-value,
        valuation-count: new-valuation-count
      }
    )
    
    (ok new-total-value)
  )
)

(define-read-only (get-land-valuation (land-id uint))
  (map-get? land-valuations { land-id: land-id })
)

(define-read-only (get-valuation-history (land-id uint) (valuation-index uint))
  (map-get? valuation-history { land-id: land-id, valuation-index: valuation-index })
)

(define-read-only (calculate-token-value (land-id uint))
  (let
    (
      (land-data (unwrap! (map-get? land-parcels { land-id: land-id }) ERR_LAND_NOT_FOUND))
      (valuation-data (unwrap! (map-get? land-valuations { land-id: land-id }) ERR_LAND_NOT_FOUND))
    )
    (ok (/ (get total-market-value valuation-data) (get total-tokens land-data)))
  )
)

(define-read-only (get-portfolio-value (investor principal) (land-id uint))
  (let
    (
      (investor-data (unwrap! (map-get? investor-holdings { investor: investor, land-id: land-id }) ERR_INSUFFICIENT_BALANCE))
      (token-value (unwrap! (calculate-token-value land-id) ERR_LAND_NOT_FOUND))
    )
    (ok (* (get tokens-held investor-data) token-value))
  )
)


(define-map farming-milestones
  { land-id: uint }
  {
    current-milestone: uint,
    season-year: uint,
    planted-block: uint,
    growing-block: uint,
    harvested-block: uint,
    growing-duration: uint,
    harvest-duration: uint
  }
)

(define-public (initialize-farming-season (land-id uint) (growing-duration uint) (harvest-duration uint))
  (let
    (
      (land-data (unwrap! (map-get? land-parcels { land-id: land-id }) ERR_LAND_NOT_FOUND))
      (existing-milestone (default-to 
        { current-milestone: u0, season-year: u0, planted-block: u0, growing-block: u0, harvested-block: u0, growing-duration: u0, harvest-duration: u0 }
        (map-get? farming-milestones { land-id: land-id })))
      (current-season (get season-year existing-milestone))
    )
    (asserts! (is-eq tx-sender (get owner land-data)) ERR_UNAUTHORIZED)
    (asserts! (get active land-data) ERR_LAND_NOT_FOUND)
    (asserts! (> growing-duration u0) ERR_INVALID_AMOUNT)
    (asserts! (> harvest-duration u0) ERR_INVALID_AMOUNT)
    
    (map-set farming-milestones
      { land-id: land-id }
      {
        current-milestone: MILESTONE_PLANTED,
        season-year: (+ current-season u1),
        planted-block: stacks-block-height,
        growing-block: u0,
        harvested-block: u0,
        growing-duration: growing-duration,
        harvest-duration: harvest-duration
      }
    )
    
    (ok MILESTONE_PLANTED)
  )
)

(define-public (advance-milestone (land-id uint))
  (let
    (
      (land-data (unwrap! (map-get? land-parcels { land-id: land-id }) ERR_LAND_NOT_FOUND))
      (milestone-data (unwrap! (map-get? farming-milestones { land-id: land-id }) ERR_LAND_NOT_FOUND))
      (current-milestone (get current-milestone milestone-data))
    )
    (asserts! (is-eq tx-sender (get owner land-data)) ERR_UNAUTHORIZED)
    (asserts! (< current-milestone MILESTONE_HARVESTED) ERR_SEASON_COMPLETE)
    
    (if (is-eq current-milestone MILESTONE_PLANTED)
      (begin
        (asserts! (>= (- stacks-block-height (get planted-block milestone-data)) (get growing-duration milestone-data)) ERR_MILESTONE_NOT_REACHED)
        (map-set farming-milestones
          { land-id: land-id }
          (merge milestone-data { current-milestone: MILESTONE_GROWING, growing-block: stacks-block-height })
        )
        (ok MILESTONE_GROWING)
      )
      (if (is-eq current-milestone MILESTONE_GROWING)
        (begin
          (asserts! (>= (- stacks-block-height (get growing-block milestone-data)) (get harvest-duration milestone-data)) ERR_MILESTONE_NOT_REACHED)
          (map-set farming-milestones
            { land-id: land-id }
            (merge milestone-data { current-milestone: MILESTONE_HARVESTED, harvested-block: stacks-block-height })
          )
          (ok MILESTONE_HARVESTED)
        )
        ERR_INVALID_MILESTONE
      )
    )
  )
)

(define-public (distribute-harvest-profits (land-id uint) (total-profit uint))
  (let
    (
      (milestone-data (unwrap! (map-get? farming-milestones { land-id: land-id }) ERR_LAND_NOT_FOUND))
    )
    (asserts! (is-eq (get current-milestone milestone-data) MILESTONE_HARVESTED) ERR_MILESTONE_NOT_REACHED)
    (distribute-profits land-id total-profit)
  )
)

(define-read-only (get-farming-milestone (land-id uint))
  (map-get? farming-milestones { land-id: land-id })
)

(define-read-only (is-harvest-ready (land-id uint))
  (match (map-get? farming-milestones { land-id: land-id })
    milestone-data (ok (is-eq (get current-milestone milestone-data) MILESTONE_HARVESTED))
    (ok false)
  )
)