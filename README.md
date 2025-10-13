# 🗳️ Participatory Budget Voting

A smart contract system for democratic budget allocation and governance on the Stacks blockchain.

## 🎯 Overview

This smart contract enables communities to democratically decide how to allocate budgets through transparent voting mechanisms. Perfect for DAOs, municipalities, or any organization wanting to implement participatory budgeting.

## ✨ Features

- 💰 **Budget Management**: Set and track total available budgets
- 📝 **Proposal Submission**: Registered voters can submit budget proposals
- 🗳️ **Democratic Voting**: Vote for or against budget proposals
- ⏰ **Time-based Voting**: Configurable voting periods for fair participation
- 🔒 **Voter Registration**: Secure voter registration system
- 📊 **Transparent Results**: Real-time vote tracking and results
- ✅ **Proposal Execution**: Finalize and execute approved proposals

## 🚀 Quick Start

### Prerequisites
- Clarinet CLI installed
- Stacks wallet for testing

### Installation

```bash
git clone <repository-url>
cd participatory-budget-voting
clarinet check
```

## 📖 Usage

### 1️⃣ Initialize the System

```clarity
;; Set the total budget (contract owner only)
(contract-call? .participatory-budget-voting set-total-budget u1000000)

;; Set voting period in blocks (default: 1008 blocks ≈ 1 week)
(contract-call? .participatory-budget-voting update-voting-period u1440)
```

### 2️⃣ Register as a Voter

```clarity
;; Any user can register to vote
(contract-call? .participatory-budget-voting register-voter)
```

### 3️⃣ Submit a Proposal

```clarity
;; Submit a budget proposal
(contract-call? .participatory-budget-voting submit-proposal 
  "Community Garden" 
  "Build a community garden in downtown area" 
  u50000)
```

### 4️⃣ Vote on Proposals

```clarity
;; Vote for a proposal (true = for, false = against)
(contract-call? .participatory-budget-voting vote-on-proposal u1 true)
```

### 5️⃣ Finalize Results

```clarity
;; Finalize voting after voting period ends (contract owner only)
(contract-call? .participatory-budget-voting finalize-proposal u1)

;; Execute approved proposal
(contract-call? .participatory-budget-voting execute-approved-proposal u1 'SP1RECIPIENT...)
```

## 🔍 Query Functions

### Get Proposal Information
```clarity
;; Get proposal details
(contract-call? .participatory-budget-voting get-proposal u1)

;; Get voting results
(contract-call? .participatory-budget-voting get-proposal-results u1)
```

### Check Budget Status
```clarity
;; Get total budget
(contract-call? .participatory-budget-voting get-total-budget)

;; Get available budget
(contract-call? .participatory-budget-voting get-available-budget)
```

### Voter Information
```clarity
;; Check if address is registered voter
(contract-call? .participatory-budget-voting is-registered-voter 'SP1VOTER...)

;; Check if voter has voted on proposal
(contract-call? .participatory-budget-voting has-voted 'SP1VOTER... u1)
```

## 📊 Contract States

### Proposal Status
- `active` - Currently accepting votes
- `approved` - Passed voting, ready for execution
- `rejected` - Failed voting
- `executed` - Funds have been allocated

## 🔐 Access Control

- **Contract Owner**: Can set budget, finalize proposals, execute approved proposals
- **Registered Voters**: Can submit proposals and vote
- **Anyone**: Can register as voter and view public information

## 🧪 Testing

```bash
# Run all tests
clarinet test

# Check contract syntax
clarinet check
```

## 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Voter         │    │   Proposals     │    │   Budget        │
│   Registry      │───▶│   Management    │───▶│   Allocation    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Voting        │    │   Results       │    │   Execution     │
│   System        │───▶│   Tracking      │───▶│   & Finalization│
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## 📄 License

This project is open source and available under the MIT License.

## 🆘 Support

- 📧 Create an issue for bug reports
- 💬 Join our Discord for discussions
- 📖 Check the documentation for detailed guides

---

Built with ❤️ for transparent governance and community empowerment.
