ContentGuard
============

A decentralized content moderation protocol for social platforms built on the Stacks blockchain using Clarity. This system enables **community-driven content moderation** by leveraging **staking**, **voting**, and **reputation** mechanisms, incentivizing honest participation and penalizing malicious behavior.

* * * * *

🚀 Overview
-----------

The **ContentGuard** contract provides a foundational layer for decentralized social platforms to manage content flags and removals without relying on a central authority. It shifts the power of moderation to a staked community of users, ensuring transparency, fairness, and censorship resistance.

### Key Features

-   **Content Creation:** Users can post content, represented by a unique hash.

-   **Decentralized Reporting:** Any user can report content by staking a minimum amount of STX, flagging the post for review.

-   **Moderator Role:** Users who maintain a high reputation score can become **Moderators**, giving them the right to vote on flagged content.

-   **Staked Voting:** Moderators vote 'For' or 'Against' a report by staking their own tokens, aligning their financial incentive with the protocol's integrity.

-   **Automated Resolution:** Reports are resolved after a fixed voting period, and the content's final status is determined by a simple majority vote.

-   **Reputation System:** Users and Moderators are rewarded or penalized based on the outcome of the reports they file or vote on, ensuring long-term honest participation.

-   **Financial Incentives:** Stakes are distributed to reward honest reporters and voters, or forfeited to penalize dishonest behavior.

* * * * *

⚙️ Contract Details
-------------------

The contract is written in **Clarity**, the smart contract language for the Stacks blockchain.

### Constants

| **Constant** | **Value** | **Description** |
| --- | --- | --- |
| `CONTRACT_OWNER` | `tx-sender` | The principal who deployed the contract (used for owner-only actions, though not explicitly used in public functions here). |
| `MIN_STAKE_AMOUNT` | `u1000000` (1 STX) | The minimum amount of STX required to file a report or vote. |
| `VOTING_PERIOD` | `u144` | The number of blocks for which a report remains open for voting (approx. 24 hours). |
| `MODERATOR_THRESHOLD` | `u5000000` (5 STX) | The minimum reputation score required for a user to become a Moderator. |
| `REPUTATION_PENALTY` | `-10` | Signed integer reduction in reputation for dishonesty (false reports, wrong votes, etc.). |
| `REPUTATION_REWARD` | `5` | Signed integer increase in reputation for honest participation (successful reports, correct votes, etc.). |

### Error Codes

| **Error Code** | **Value** | **Description** |
| --- | --- | --- |
| `ERR_NOT_AUTHORIZED` | `u100` | Transaction sender lacks required authority (e.g., trying to become moderator without sufficient reputation). |
| `ERR_POST_NOT_FOUND` | `u101` | The specified post ID does not exist. |
| `ERR_ALREADY_REPORTED` | `u102` | An attempt was made to create a report that already exists. |
| `ERR_INSUFFICIENT_STAKE` | `u103` | The provided stake amount is less than `MIN_STAKE_AMOUNT`. |
| `ERR_VOTING_PERIOD_ENDED` | `u104` | Attempting to vote on a report after the voting period has ended or if the report is already resolved. |
| `ERR_ALREADY_VOTED` | `u105` | A user is attempting to vote on the same report twice. |
| `ERR_INVALID_VOTE` | `u106` | A resolution attempt failed because no votes were cast (`total-votes == u0`). |
| `ERR_NOT_MODERATOR` | `u107` | Transaction sender attempted a Moderator-only action without having the role. |

### Data Maps and Variables

| **Data Structure** | **Type** | **Description** |
| --- | --- | --- |
| `posts` | Map | Stores content details: `author`, `content-hash`, `timestamp`, `status` (`"active"`, `"flagged"`, `"removed"`), and `reports-count`. |
| `reports` | Map | Stores report details: `post-id`, `reporter`, `reason`, `stake-amount`, `timestamp`, vote counts (`votes-for`, `votes-against`), and `resolved` status. |
| `user-reputation` | Map | Tracks user-specific data: `reputation` score (defaulting to u100) and `is-moderator` boolean flag. |
| `report-votes` | Map | Records individual moderator votes: `vote` (`bool`) and `stake` amount. |
| `next-post-id` | Data Var | Auto-incrementing counter for new posts. |
| `next-report-id` | Data Var | Auto-incrementing counter for new reports. |
| `total-staked` | Data Var | Tracks the total STX currently staked within the contract. |

* * * * *

🔒 Private Functions (Internal Logic)
-------------------------------------

These functions encapsulate core logic for managing the reputation system and checking user roles, ensuring clean separation of concerns and maintainability.

### `(is-moderator (user principal))`

Checks if a given principal holds the Moderator role by querying the `user-reputation` map.

-   **Input:** `user` (principal)

-   **Output:** `(bool)` - `true` if the user is a moderator, `false` otherwise.

### `(get-user-reputation (user principal))`

Retrieves the current reputation score for a given principal. Defaults to **u100** if no entry is found for the user, establishing a base reputation for new users.

-   **Input:** `user` (principal)

-   **Output:** `(uint)` - The user's reputation score.

### `(update-reputation (user principal) (change int))`

The core function for modifying a user's reputation score. It handles both positive (rewards) and negative (penalties) changes. It also ensures the score does not fall below zero.

-   **Inputs:**

    -   `user` (principal): The user whose reputation is being updated.

    -   `change` (int): The amount of change. Positive for rewards, negative for penalties.

-   **Output:** `(response bool unit)` - Returns `(ok true)` upon successful update.

* * * * *

🛠️ Public Functions (Entrypoints)
----------------------------------

### `(create-post (content-hash (string-ascii 64)))`

Creates a new content entry, marking the user as the `author` and setting the initial `status` to `"active"`.

### `(report-content (post-id uint) (reason (string-ascii 100)) (stake-amount uint))`

Transfers `stake-amount` STX from `tx-sender` to the contract, creates a new report, and sets the post's status to `"flagged"`. Requires a minimum stake.

### `(become-moderator)`

Allows `tx-sender` to opt-in to the Moderator role if their current reputation (retrieved via `get-user-reputation`) is greater than or equal to `MODERATOR_THRESHOLD`.

### `(vote-on-report (report-id uint) (vote bool) (stake-amount uint))`

Transfers `stake-amount` STX from the moderator to the contract, records their vote (`true` for uphold/remove, `false` for reject/keep), and updates the report's aggregate vote counts. Requires the sender to be an active moderator and the voting period to be active.

### `(resolve-report-and-distribute-rewards (report-id uint))`

Executed after the `VOTING_PERIOD` ends. This function determines the final outcome based on a majority vote, resolves the post status, and adjusts reputation and stakes:

-   **Report Upheld:** Post removed. Post Author penalized. Reporter rewarded and stake returned **plus bonus**.

-   **Report Rejected:** Post status returns to "active". Reporter penalized. Post Author rewarded. Reporter's stake **forfeited** to the Post Author.

* * * * *

⚠️ Known Limitation (Voter Rewards)
-----------------------------------

The current implementation of `resolve-report-and-distribute-rewards` correctly handles the **Reporter's stake** and the **Reputation updates** for the Reporter and Post Author. However, it only updates the `total-staked` variable by subtracting the reporter's stake and **does not iterate through the `report-votes` map** to refund or reward the individual Moderators who voted. In a fully productionized version, a loop or a separate mechanism would be required to distribute the accumulated stakes proportionally to the moderators who voted correctly (i.e., aligning with the majority outcome).

* * * * *

🤝 Contribution
---------------

We welcome contributions to the ContentGuard protocol! Whether it's reporting bugs, suggesting improvements to the economic model, or adding new features (like iterating through all voters for reward distribution), your input is valuable.

### How to Contribute

1.  **Fork** the repository.

2.  **Clone** your fork.

3.  Create a new feature branch (`git checkout -b feature/awesome-new-feature`).

4.  Commit your changes (`git commit -am 'Feat: Add an awesome new feature'`).

5.  Push to the branch (`git push origin feature/awesome-new-feature`).

6.  Open a **Pull Request** and describe your changes thoroughly.

### Development Guidelines

-   All code must be written in **Clarity**.

-   Follow the Clarity convention for naming: `kebab-case` for functions and variables.

-   Include comprehensive **unit tests** for any new functionality using the Clarinet testing harness.

-   Ensure all new entrypoints have appropriate authorization and error handling.

* * * * *

⚖️ License
----------

This project is licensed under the **MIT License** - see the full text below.

### The MIT License (MIT)

Copyright (c) 2025 The ContentGuard Protocol Developers

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
