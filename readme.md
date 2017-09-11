First attempt at a simplified prediction market.

TODO:
====

 - let a hub pause its contracts, suicide them, and change their owner
 - testing! figure out how to do things in solidity, or write JS tests.
 - incentivise the trusted oracle, and integrate with a real oracle
 - UI!
 - A way for owner to spend ERC20 tokens that are received by mistake (hub and qn)
 - Future enhancement exercise: a proper pricing algorithm!
 - other `TODO`s and `QUESTION`s in code


CHANGE LOG
======

Version 0.2 = refinements, and hub+spoke. Still untested!
-----------

- First code review mark-ups (feedback from Rob Hitchens)
     - simplify resolve
     - avoid using this.balance
     - generally simplify where possible
     - consider return codes
- Add sponsor deposit
- Hub and spoke deployment, with commission to hub
- Initial testing

Version 0.1 = INITIAL CHECKIN
======

Work in progress