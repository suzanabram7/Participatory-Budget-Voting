(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_PROPOSAL_NOT_FOUND (err u101))
(define-constant ERR_VOTING_CLOSED (err u102))
(define-constant ERR_ALREADY_VOTED (err u103))
(define-constant ERR_INSUFFICIENT_BUDGET (err u104))
(define-constant ERR_PROPOSAL_ALREADY_EXISTS (err u105))
(define-constant ERR_INVALID_AMOUNT (err u106))
(define-constant ERR_VOTING_NOT_ENDED (err u107))
(define-constant ERR_DELEGATION_CYCLE (err u108))
(define-constant ERR_SELF_DELEGATION (err u109))
(define-constant ERR_DELEGATE_NOT_REGISTERED (err u110))

(define-data-var total-budget uint u0)
(define-data-var allocated-budget uint u0)
(define-data-var voting-period uint u1008)
(define-data-var proposal-counter uint u0)

(define-map proposals
  { proposal-id: uint }
  {
    title: (string-ascii 64),
    description: (string-ascii 256),
    amount: uint,
    proposer: principal,
    votes-for: uint,
    votes-against: uint,
    created-at: uint,
    status: (string-ascii 16)
  }
)

(define-map votes
  { voter: principal, proposal-id: uint }
  { vote: bool, voted-at: uint }
)

(define-map voter-registry
  { voter: principal }
  { is-registered: bool, registration-block: uint }
)

(define-map delegation
  { delegator: principal }
  { delegate: principal, delegated-at: uint }
)

(define-public (set-total-budget (amount uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (var-set total-budget amount)
    (ok true)
  )
)

(define-public (register-voter)
  (begin
    (map-set voter-registry 
      { voter: tx-sender }
      { is-registered: true, registration-block: stacks-block-height }
    )
    (ok true)
  )
)

(define-public (submit-proposal (title (string-ascii 64)) (description (string-ascii 256)) (amount uint))
  (let
    (
      (proposal-id (+ (var-get proposal-counter) u1))
      (current-allocated (var-get allocated-budget))
      (total (var-get total-budget))
    )
    (asserts! (is-registered-voter tx-sender) ERR_NOT_AUTHORIZED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (<= (+ current-allocated amount) total) ERR_INSUFFICIENT_BUDGET)
    
    (map-set proposals
      { proposal-id: proposal-id }
      {
        title: title,
        description: description,
        amount: amount,
        proposer: tx-sender,
        votes-for: u0,
        votes-against: u0,
        created-at: stacks-block-height,
        status: "active"
      }
    )
    (var-set proposal-counter proposal-id)
    (ok proposal-id)
  )
)

(define-public (vote-on-proposal (proposal-id uint) (vote-for bool))
  (let
    (
      (proposal (unwrap! (map-get? proposals { proposal-id: proposal-id }) ERR_PROPOSAL_NOT_FOUND))
      (voter-info (unwrap! (map-get? voter-registry { voter: tx-sender }) ERR_NOT_AUTHORIZED))
      (existing-vote (map-get? votes { voter: tx-sender, proposal-id: proposal-id }))
      (delegation-info (map-get? delegation { delegator: tx-sender }))
      (final-voter (match delegation-info
                     some-delegation (get delegate some-delegation)
                     tx-sender))
    )
    (asserts! (get is-registered voter-info) ERR_NOT_AUTHORIZED)
    (asserts! (is-none existing-vote) ERR_ALREADY_VOTED)
    (asserts! (is-eq (get status proposal) "active") ERR_VOTING_CLOSED)
    (asserts! (<= (get created-at proposal) (- stacks-block-height (var-get voting-period))) ERR_VOTING_NOT_ENDED)
    
    (map-set votes
      { voter: final-voter, proposal-id: proposal-id }
      { vote: vote-for, voted-at: stacks-block-height }
    )
    
    (if vote-for
      (map-set proposals
        { proposal-id: proposal-id }
        (merge proposal { votes-for: (+ (get votes-for proposal) u1) })
      )
      (map-set proposals
        { proposal-id: proposal-id }
        (merge proposal { votes-against: (+ (get votes-against proposal) u1) })
      )
    )
    (ok true)
  )
)

(define-public (finalize-proposal (proposal-id uint))
  (let
    (
      (proposal (unwrap! (map-get? proposals { proposal-id: proposal-id }) ERR_PROPOSAL_NOT_FOUND))
      (votes-for (get votes-for proposal))
      (votes-against (get votes-against proposal))
      (proposal-amount (get amount proposal))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq (get status proposal) "active") ERR_VOTING_CLOSED)
    (asserts! (>= stacks-block-height (+ (get created-at proposal) (var-get voting-period))) ERR_VOTING_NOT_ENDED)
    
    (if (> votes-for votes-against)
      (begin
        (map-set proposals
          { proposal-id: proposal-id }
          (merge proposal { status: "approved" })
        )
        (var-set allocated-budget (+ (var-get allocated-budget) proposal-amount))
        (ok "approved")
      )
      (begin
        (map-set proposals
          { proposal-id: proposal-id }
          (merge proposal { status: "rejected" })
        )
        (ok "rejected")
      )
    )
  )
)

(define-public (execute-approved-proposal (proposal-id uint) (recipient principal))
  (let
    (
      (proposal (unwrap! (map-get? proposals { proposal-id: proposal-id }) ERR_PROPOSAL_NOT_FOUND))
      (proposal-amount (get amount proposal))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq (get status proposal) "approved") ERR_NOT_AUTHORIZED)
    
    (map-set proposals
      { proposal-id: proposal-id }
      (merge proposal { status: "executed" })
    )
    (ok proposal-amount)
  )
)

(define-public (update-voting-period (new-period uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (> new-period u0) ERR_INVALID_AMOUNT)
    (var-set voting-period new-period)
    (ok true)
  )
)

(define-public (delegate-vote (delegate principal))
  (begin
    (asserts! (is-registered-voter tx-sender) ERR_NOT_AUTHORIZED)
    (asserts! (is-registered-voter delegate) ERR_DELEGATE_NOT_REGISTERED)
    (asserts! (not (is-eq tx-sender delegate)) ERR_SELF_DELEGATION)
    (asserts! (not (creates-delegation-cycle tx-sender delegate)) ERR_DELEGATION_CYCLE)
    
    (map-set delegation
      { delegator: tx-sender }
      { delegate: delegate, delegated-at: stacks-block-height }
    )
    (ok true)
  )
)

(define-public (revoke-delegation)
  (begin
    (asserts! (is-registered-voter tx-sender) ERR_NOT_AUTHORIZED)
    
    (map-delete delegation { delegator: tx-sender })
    (ok true)
  )
)

(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals { proposal-id: proposal-id })
)

(define-read-only (get-vote (voter principal) (proposal-id uint))
  (map-get? votes { voter: voter, proposal-id: proposal-id })
)

(define-read-only (is-registered-voter (voter principal))
  (default-to false 
    (get is-registered 
      (map-get? voter-registry { voter: voter })
    )
  )
)

(define-read-only (get-total-budget)
  (var-get total-budget)
)

(define-read-only (get-allocated-budget)
  (var-get allocated-budget)
)

(define-read-only (get-available-budget)
  (- (var-get total-budget) (var-get allocated-budget))
)

(define-read-only (get-voting-period)
  (var-get voting-period)
)

(define-read-only (get-proposal-count)
  (var-get proposal-counter)
)

(define-read-only (get-proposal-status (proposal-id uint))
  (match (map-get? proposals { proposal-id: proposal-id })
    proposal (some (get status proposal))
    none
  )
)

(define-read-only (get-proposal-results (proposal-id uint))
  (match (map-get? proposals { proposal-id: proposal-id })
    proposal (some {
      votes-for: (get votes-for proposal),
      votes-against: (get votes-against proposal),
      total-votes: (+ (get votes-for proposal) (get votes-against proposal)),
      status: (get status proposal)
    })
    none
  )
)

(define-read-only (has-voted (voter principal) (proposal-id uint))
  (is-some (map-get? votes { voter: voter, proposal-id: proposal-id }))
)

(define-read-only (get-contract-info)
  {
    total-budget: (var-get total-budget),
    allocated-budget: (var-get allocated-budget),
    available-budget: (- (var-get total-budget) (var-get allocated-budget)),
    voting-period: (var-get voting-period),
    proposal-count: (var-get proposal-counter),
    contract-owner: CONTRACT_OWNER
  }
)

(define-read-only (get-delegation (delegator principal))
  (map-get? delegation { delegator: delegator })
)

(define-read-only (is-delegated (voter principal))
  (is-some (map-get? delegation { delegator: voter }))
)

(define-read-only (get-final-delegate (voter principal))
  (match (map-get? delegation { delegator: voter })
    delegation-info (get delegate delegation-info)
    voter
  )
)

(define-read-only (creates-delegation-cycle (delegator principal) (new-delegate principal))
  (is-eq delegator new-delegate)
)

(define-read-only (count-delegated-votes (delegate principal))
  u0
)

(define-read-only (get-voting-power (voter principal))
  (if (is-registered-voter voter)
    u1
    u0
  )
)