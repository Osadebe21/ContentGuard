;; Web3 Content Moderation Protocol
;; A decentralized content moderation system for social platforms that enables 
;; community-driven moderation through staking, voting, and reputation mechanisms

;; constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_POST_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_REPORTED (err u102))
(define-constant ERR_INSUFFICIENT_STAKE (err u103))
(define-constant ERR_VOTING_PERIOD_ENDED (err u104))
(define-constant ERR_ALREADY_VOTED (err u105))
(define-constant ERR_INVALID_VOTE (err u106))
(define-constant ERR_NOT_MODERATOR (err u107))

(define-constant MIN_STAKE_AMOUNT u1000000) ;; 1 STX minimum stake
(define-constant VOTING_PERIOD u144) ;; ~24 hours in blocks
(define-constant MODERATOR_THRESHOLD u5000000) ;; 5 STX to become moderator
(define-constant REPUTATION_PENALTY 10) ;; Signed integer for penalties
(define-constant REPUTATION_REWARD 5) ;; Signed integer for rewards

;; data maps and vars
(define-map posts 
  { post-id: uint }
  {
    author: principal,
    content-hash: (string-ascii 64),
    timestamp: uint,
    status: (string-ascii 20), ;; "active", "flagged", "removed"
    reports-count: uint
  }
)

(define-map reports
  { report-id: uint }
  {
    post-id: uint,
    reporter: principal,
    reason: (string-ascii 100),
    stake-amount: uint,
    timestamp: uint,
    votes-for: uint,
    votes-against: uint,
    resolved: bool
  }
)

(define-map user-reputation
  { user: principal }
  { reputation: uint, is-moderator: bool }
)

(define-map report-votes
  { report-id: uint, voter: principal }
  { vote: bool, stake: uint }
)

(define-data-var next-post-id uint u1)
(define-data-var next-report-id uint u1)
(define-data-var total-staked uint u0)

;; private functions
(define-private (is-moderator (user principal))
  (default-to false 
    (get is-moderator (map-get? user-reputation { user: user }))
  )
)

(define-private (get-user-reputation (user principal))
  (default-to u100 
    (get reputation (map-get? user-reputation { user: user }))
  )
)

(define-private (update-reputation (user principal) (change int))
  (let ((current-rep (get-user-reputation user)))
    (map-set user-reputation
      { user: user }
      {
        reputation: (if (> change 0)
                     (+ current-rep (to-uint change))
                     (if (> current-rep (to-uint (* change -1)))
                       (- current-rep (to-uint (* change -1)))
                       u0)),
        is-moderator: (is-moderator user)
      }
    )
  )
)

;; public functions
(define-public (create-post (content-hash (string-ascii 64)))
  (let ((post-id (var-get next-post-id)))
    (map-set posts
      { post-id: post-id }
      {
        author: tx-sender,
        content-hash: content-hash,
        timestamp: block-height,
        status: "active",
        reports-count: u0
      }
    )
    (var-set next-post-id (+ post-id u1))
    (ok post-id)
  )
)

(define-public (report-content (post-id uint) (reason (string-ascii 100)) (stake-amount uint))
  (let ((post (unwrap! (map-get? posts { post-id: post-id }) ERR_POST_NOT_FOUND))
        (report-id (var-get next-report-id)))
    
    (asserts! (>= stake-amount MIN_STAKE_AMOUNT) ERR_INSUFFICIENT_STAKE)
    (asserts! (is-none (map-get? reports { report-id: report-id })) ERR_ALREADY_REPORTED)
    
    ;; Transfer stake to contract
    (try! (stx-transfer? stake-amount tx-sender (as-contract tx-sender)))
    
    (map-set reports
      { report-id: report-id }
      {
        post-id: post-id,
        reporter: tx-sender,
        reason: reason,
        stake-amount: stake-amount,
        timestamp: block-height,
        votes-for: u0,
        votes-against: u0,
        resolved: false
      }
    )
    
    ;; Update post reports count
    (map-set posts
      { post-id: post-id }
      (merge post { 
        reports-count: (+ (get reports-count post) u1),
        status: "flagged"
      })
    )
    
    (var-set next-report-id (+ report-id u1))
    (var-set total-staked (+ (var-get total-staked) stake-amount))
    (ok report-id)
  )
)

(define-public (become-moderator)
  (let ((user-rep (get-user-reputation tx-sender)))
    (asserts! (>= user-rep MODERATOR_THRESHOLD) ERR_NOT_AUTHORIZED)
    
    (map-set user-reputation
      { user: tx-sender }
      {
        reputation: user-rep,
        is-moderator: true
      }
    )
    (ok true)
  )
)

(define-public (vote-on-report (report-id uint) (vote bool) (stake-amount uint))
  (let ((report (unwrap! (map-get? reports { report-id: report-id }) ERR_POST_NOT_FOUND)))
    
    (asserts! (is-moderator tx-sender) ERR_NOT_MODERATOR)
    (asserts! (< (+ (get timestamp report) VOTING_PERIOD) block-height) ERR_VOTING_PERIOD_ENDED)
    (asserts! (>= stake-amount MIN_STAKE_AMOUNT) ERR_INSUFFICIENT_STAKE)
    (asserts! (is-none (map-get? report-votes { report-id: report-id, voter: tx-sender })) ERR_ALREADY_VOTED)
    (asserts! (not (get resolved report)) ERR_VOTING_PERIOD_ENDED)
    
    ;; Transfer stake to contract
    (try! (stx-transfer? stake-amount tx-sender (as-contract tx-sender)))
    
    ;; Record vote
    (map-set report-votes
      { report-id: report-id, voter: tx-sender }
      { vote: vote, stake: stake-amount }
    )
    
    ;; Update report vote counts
    (map-set reports
      { report-id: report-id }
      (merge report {
        votes-for: (if vote (+ (get votes-for report) u1) (get votes-for report)),
        votes-against: (if vote (get votes-against report) (+ (get votes-against report) u1))
      })
    )
    
    (var-set total-staked (+ (var-get total-staked) stake-amount))
    (ok true)
  )
)


