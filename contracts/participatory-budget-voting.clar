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
(define-constant ERR_CATEGORY_NOT_FOUND (err u111))
(define-constant ERR_CATEGORY_BUDGET_EXCEEDED (err u112))
(define-constant ERR_CATEGORY_EXISTS (err u113))
(define-constant ERR_QUORUM_NOT_REACHED (err u114))
(define-constant ERR_NOT_PROPOSER (err u115))
(define-constant ERR_PROPOSAL_NOT_CANCELLABLE (err u116))

(define-data-var total-budget uint u0)
(define-data-var allocated-budget uint u0)
(define-data-var voting-period uint u1008)
(define-data-var proposal-counter uint u0)
(define-data-var category-counter uint u0)
(define-data-var quorum-percentage uint u20)
(define-data-var total-registered-voters uint u0)

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
    status: (string-ascii 16),
    category-id: uint
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

(define-map categories
  { category-id: uint }
  {
    name: (string-ascii 32),
    description: (string-ascii 128),
    budget-limit: uint,
    allocated: uint,
    created-at: uint,
    is-active: bool
  }
)

(define-map category-name-lookup
  { name: (string-ascii 32) }
  { category-id: uint }
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
  (let
    (
      (existing-voter (map-get? voter-registry { voter: tx-sender }))
    )
    (if (is-none existing-voter)
      (var-set total-registered-voters (+ (var-get total-registered-voters) u1))
      true
    )
    (map-set voter-registry 
      { voter: tx-sender }
      { is-registered: true, registration-block: stacks-block-height }
    )
    (ok true)
  )
)

(define-public (create-category (name (string-ascii 32)) (description (string-ascii 128)) (budget-limit uint))
  (let
    (
      (category-id (+ (var-get category-counter) u1))
      (existing-category (map-get? category-name-lookup { name: name }))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (> budget-limit u0) ERR_INVALID_AMOUNT)
    (asserts! (is-none existing-category) ERR_CATEGORY_EXISTS)
    
    (map-set categories
      { category-id: category-id }
      {
        name: name,
        description: description,
        budget-limit: budget-limit,
        allocated: u0,
        created-at: stacks-block-height,
        is-active: true
      }
    )
    
    (map-set category-name-lookup
      { name: name }
      { category-id: category-id }
    )
    
    (var-set category-counter category-id)
    (ok category-id)
  )
)

(define-public (update-category-budget (category-id uint) (new-budget-limit uint))
  (let
    (
      (category (unwrap! (map-get? categories { category-id: category-id }) ERR_CATEGORY_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (> new-budget-limit u0) ERR_INVALID_AMOUNT)
    (asserts! (get is-active category) ERR_CATEGORY_NOT_FOUND)
    
    (map-set categories
      { category-id: category-id }
      (merge category { budget-limit: new-budget-limit })
    )
    (ok true)
  )
)

(define-public (toggle-category-status (category-id uint))
  (let
    (
      (category (unwrap! (map-get? categories { category-id: category-id }) ERR_CATEGORY_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    
    (map-set categories
      { category-id: category-id }
      (merge category { is-active: (not (get is-active category)) })
    )
    (ok true)
  )
)

(define-public (submit-proposal (title (string-ascii 64)) (description (string-ascii 256)) (amount uint) (category-id uint))
  (let
    (
      (proposal-id (+ (var-get proposal-counter) u1))
      (current-allocated (var-get allocated-budget))
      (total (var-get total-budget))
      (category (unwrap! (map-get? categories { category-id: category-id }) ERR_CATEGORY_NOT_FOUND))
      (category-allocated (get allocated category))
      (category-limit (get budget-limit category))
    )
    (asserts! (is-registered-voter tx-sender) ERR_NOT_AUTHORIZED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (get is-active category) ERR_CATEGORY_NOT_FOUND)
    (asserts! (<= (+ current-allocated amount) total) ERR_INSUFFICIENT_BUDGET)
    (asserts! (<= (+ category-allocated amount) category-limit) ERR_CATEGORY_BUDGET_EXCEEDED)
    
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
        status: "active",
        category-id: category-id
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
      (total-votes (+ votes-for votes-against))
      (proposal-amount (get amount proposal))
      (proposal-category-id (get category-id proposal))
      (category (unwrap! (map-get? categories { category-id: proposal-category-id }) ERR_CATEGORY_NOT_FOUND))
      (quorum-required (calculate-quorum-threshold))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq (get status proposal) "active") ERR_VOTING_CLOSED)
    (asserts! (>= stacks-block-height (+ (get created-at proposal) (var-get voting-period))) ERR_VOTING_NOT_ENDED)
    (asserts! (>= total-votes quorum-required) ERR_QUORUM_NOT_REACHED)
    
    (if (> votes-for votes-against)
      (begin
        (map-set proposals
          { proposal-id: proposal-id }
          (merge proposal { status: "approved" })
        )
        (map-set categories
          { category-id: proposal-category-id }
          (merge category { allocated: (+ (get allocated category) proposal-amount) })
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

(define-public (cancel-proposal (proposal-id uint))
  (let
    (
      (proposal (unwrap! (map-get? proposals { proposal-id: proposal-id }) ERR_PROPOSAL_NOT_FOUND))
      (proposer (get proposer proposal))
      (votes-for (get votes-for proposal))
      (votes-against (get votes-against proposal))
      (total-votes (+ votes-for votes-against))
    )
    (asserts! (or (is-eq tx-sender proposer) (is-eq tx-sender CONTRACT_OWNER)) ERR_NOT_PROPOSER)
    (asserts! (is-eq (get status proposal) "active") ERR_PROPOSAL_NOT_CANCELLABLE)
    (asserts! (is-eq total-votes u0) ERR_PROPOSAL_NOT_CANCELLABLE)
    (map-set proposals
      { proposal-id: proposal-id }
      (merge proposal { status: "cancelled" })
    )
    (ok true)
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

(define-public (set-quorum-percentage (new-percentage uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (<= new-percentage u100) ERR_INVALID_AMOUNT)
    (var-set quorum-percentage new-percentage)
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

(define-read-only (get-category (category-id uint))
  (map-get? categories { category-id: category-id })
)

(define-read-only (get-category-by-name (name (string-ascii 32)))
  (match (map-get? category-name-lookup { name: name })
    lookup (map-get? categories { category-id: (get category-id lookup) })
    none
  )
)

(define-read-only (get-category-budget-info (category-id uint))
  (match (map-get? categories { category-id: category-id })
    category (some {
      budget-limit: (get budget-limit category),
      allocated: (get allocated category),
      available: (- (get budget-limit category) (get allocated category))
    })
    none
  )
)

(define-read-only (get-category-count)
  (var-get category-counter)
)

(define-read-only (get-proposals-by-category (category-id uint))
  category-id
)

(define-read-only (is-category-active (category-id uint))
  (match (map-get? categories { category-id: category-id })
    category (get is-active category)
    false
  )
)

(define-read-only (calculate-quorum-threshold)
  (let
    (
      (total-voters (var-get total-registered-voters))
      (quorum-pct (var-get quorum-percentage))
    )
    (/ (* total-voters quorum-pct) u100)
  )
)

(define-read-only (check-quorum-status (proposal-id uint))
  (match (map-get? proposals { proposal-id: proposal-id })
    proposal 
      (let
        (
          (total-votes (+ (get votes-for proposal) (get votes-against proposal)))
          (quorum-required (calculate-quorum-threshold))
        )
        (some {
          total-votes: total-votes,
          quorum-required: quorum-required,
          quorum-reached: (>= total-votes quorum-required)
        })
      )
    none
  )
)

(define-read-only (get-quorum-percentage)
  (var-get quorum-percentage)
)

(define-read-only (get-total-registered-voters)
  (var-get total-registered-voters)
)

(define-read-only (get-governance-parameters)
  {
    total-budget: (var-get total-budget),
    allocated-budget: (var-get allocated-budget),
    voting-period: (var-get voting-period),
    quorum-percentage: (var-get quorum-percentage),
    total-registered-voters: (var-get total-registered-voters),
    quorum-threshold: (calculate-quorum-threshold),
    proposal-count: (var-get proposal-counter),
    category-count: (var-get category-counter)
  }
)

(define-constant ERR_MILESTONE_NOT_FOUND (err u117))
(define-constant ERR_PROPOSAL_NOT_APPROVED (err u118))
(define-constant ERR_MILESTONE_AMOUNT_EXCEEDED (err u119))

(define-map milestones
  { proposal-id: uint, milestone-id: uint }
  {
    title: (string-ascii 64),
    description: (string-ascii 256),
    amount: uint,
    status: (string-ascii 16),
    created-at: uint
  }
)

(define-map milestone-counters
  { proposal-id: uint }
  { count: uint }
)

(define-map milestone-allocations
  { proposal-id: uint }
  { allocated: uint }
)

(define-public (create-milestone (proposal-id uint) (title (string-ascii 64)) (description (string-ascii 256)) (amount uint))
  (let
    (
      (proposal (unwrap! (map-get? proposals { proposal-id: proposal-id }) ERR_PROPOSAL_NOT_FOUND))
      (proposer (get proposer proposal))
      (status (get status proposal))
      (proposal-amount (get amount proposal))
      (counter-entry (map-get? milestone-counters { proposal-id: proposal-id }))
      (current-count (default-to u0 (get count counter-entry)))
      (new-id (+ current-count u1))
      (allocation-entry (map-get? milestone-allocations { proposal-id: proposal-id }))
      (current-allocated (default-to u0 (get allocated allocation-entry)))
    )
    (asserts! (or (is-eq tx-sender proposer) (is-eq tx-sender CONTRACT_OWNER)) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq status "approved") ERR_PROPOSAL_NOT_APPROVED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (<= (+ current-allocated amount) proposal-amount) ERR_MILESTONE_AMOUNT_EXCEEDED)
    (map-set milestones
      { proposal-id: proposal-id, milestone-id: new-id }
      { title: title, description: description, amount: amount, status: "pending", created-at: stacks-block-height }
    )
    (map-set milestone-counters
      { proposal-id: proposal-id }
      { count: new-id }
    )
    (map-set milestone-allocations
      { proposal-id: proposal-id }
      { allocated: (+ current-allocated amount) }
    )
    (ok new-id)
  )
)

(define-public (update-milestone-status (proposal-id uint) (milestone-id uint) (new-status (string-ascii 16)))
  (let
    (
      (milestone (unwrap! (map-get? milestones { proposal-id: proposal-id, milestone-id: milestone-id }) ERR_MILESTONE_NOT_FOUND))
      (proposal (unwrap! (map-get? proposals { proposal-id: proposal-id }) ERR_PROPOSAL_NOT_FOUND))
      (proposer (get proposer proposal))
    )
    (asserts! (or (is-eq tx-sender proposer) (is-eq tx-sender CONTRACT_OWNER)) ERR_NOT_AUTHORIZED)
    (map-set milestones
      { proposal-id: proposal-id, milestone-id: milestone-id }
      (merge milestone { status: new-status })
    )
    (ok true)
  )
)

(define-read-only (get-milestone (proposal-id uint) (milestone-id uint))
  (map-get? milestones { proposal-id: proposal-id, milestone-id: milestone-id })
)

(define-read-only (get-milestone-count (proposal-id uint))
  (default-to u0 (get count (map-get? milestone-counters { proposal-id: proposal-id })))
)

(define-read-only (get-milestone-allocation (proposal-id uint))
  (default-to u0 (get allocated (map-get? milestone-allocations { proposal-id: proposal-id })))
)
