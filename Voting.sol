// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Voting is Ownable {
    struct Voter {
        bool isRegistered;
        bool hasVoted;
        uint votedProposalId;
    }

    struct Proposal {
        string description;
        uint voteCount;
    }

    enum WorkflowStatus {
        RegisteringVoters,
        ProposalsRegistrationStarted,
        ProposalsRegistrationEnded,
        VotingSessionStarted,
        VotingSessionEnded,
        VotesTallied
    }

    mapping(address => Voter) voters;

    Proposal[] proposals;
    WorkflowStatus votingStatus = WorkflowStatus.RegisteringVoters;
    uint winningProposalId;

    event VoterRegistered(address voterAddress);
    event WorkflowStatusChange(WorkflowStatus previousStatus, WorkflowStatus newStatus);
    event ProposalRegistered(uint proposalId);
    event Voted(address voter, uint proposalId);

    constructor(address initialOwner) Ownable(initialOwner) {}

    // Register a voter
    function registerVoter(address _address) external onlyOwner {
        require(votingStatus == WorkflowStatus.RegisteringVoters, "You can't register voter.");

        // Check if the address is already registered
        if(voters[_address].isRegistered){
            revert("This address is already registered.");
        }

        voters[_address] = Voter(true, false, 0);
        emit VoterRegistered(_address);
    }

    // Open proposal session
    function openProposalSession() external onlyOwner {
        require(votingStatus == WorkflowStatus.RegisteringVoters, "You can't open proposal session.");

        changeWorkflowStatus(WorkflowStatus.ProposalsRegistrationStarted);
    }

    // Close proposal session
    function closeProposalSession() external onlyOwner {
        require(votingStatus == WorkflowStatus.ProposalsRegistrationStarted, "You can't close proposal session.");

        changeWorkflowStatus(WorkflowStatus.ProposalsRegistrationEnded);
    }

    // Voter proposal
    function makeProposal(string calldata _description) external checkVoterIsRegistered(msg.sender) {
        require(votingStatus == WorkflowStatus.ProposalsRegistrationStarted, "You can't make a proposal.");

        proposals.push(Proposal(_description, 0));
        
        // Get proposal id
        uint proposalId = proposals.length - 1;

        emit ProposalRegistered(proposalId);
    }

    // Open vote session
    function openVoteSession() external onlyOwner {
        require(votingStatus == WorkflowStatus.ProposalsRegistrationEnded, "You can't open vote session.");

        // Check if vote session is already opened
        if(votingStatus == WorkflowStatus.VotingSessionStarted){
            revert("The vote session is already opened !");
        }

        // Check if there are proposals
        if(proposals.length == 0){
            revert("You can't open vote session if there aren't proposals.");
        }

        changeWorkflowStatus(WorkflowStatus.VotingSessionStarted);
    }

    // Close vote session
    function closeVoteSession() external onlyOwner {
        require(votingStatus == WorkflowStatus.VotingSessionStarted, "You can't close vote session.");

        // Check if vote session is already closed
        if(votingStatus == WorkflowStatus.VotingSessionEnded){
            revert("The vote session is already closed !");
        }

        changeWorkflowStatus(WorkflowStatus.VotingSessionEnded);

        // Set the winning proposal
        setWinningProposal();
    }

    // Voting
    function voting(uint _proposalId) external checkVoterIsRegistered(msg.sender) {
        // Check if vote session has started
        require(votingStatus == WorkflowStatus.VotingSessionStarted, "The vote session isn't started.");

        // Check if voter as already voted
        if(voters[msg.sender].hasVoted){
            revert("You have already voted");
        }

        // Check if proposal exist
        if(bytes(proposals[_proposalId].description).length == 0){
            revert("This proposal doesn't exist.");
        }
        
        proposals[_proposalId].voteCount++;

        // Set voter has voted and proposal id
        voters[msg.sender].hasVoted = true;
        voters[msg.sender].votedProposalId = _proposalId;

        emit Voted(msg.sender, _proposalId);
    }

    // Set winning proposal
    function setWinningProposal() internal {
        uint winner = 0;

        for (uint i = 0; i < proposals.length; i++) {
            if (proposals[i].voteCount > proposals[winner].voteCount) {
                winner = i;
            }
        }

        winningProposalId = winner;
        changeWorkflowStatus(WorkflowStatus.VotesTallied);
    }

    // Get description of winning proposal
    function getWinningProposal() external view returns(string memory) {
        // Check if votes is tallied
        require(votingStatus == WorkflowStatus.VotesTallied, "The votes aren't tallied.");

        return proposals[winningProposalId].description;
    }

    // Change worfklow status
    function changeWorkflowStatus(WorkflowStatus newStatus) internal  {
        WorkflowStatus previousStatus = votingStatus;
        votingStatus = newStatus;

        // Emit event workflow status change
        emit WorkflowStatusChange(previousStatus, newStatus);
    }

    // Check if voter is registered
    modifier checkVoterIsRegistered (address _address) {
        require(voters[_address].isRegistered, "You are not registered.");
        _;
    }
}