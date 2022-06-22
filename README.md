# NChatCore
iOS client for chat_core

NChatCore
========



XMPPCore
========

This library provides a set of highlevel APIs and the constructs to construct abstract new APIs to communicate with an XMPP server.
The library is built in a bottom up fashion in several layers enabling easy extensability. It's encuraged to construct new APIs
rather than force a ill fitting pattern onto an existing one.

Core
----
The core component handles all core XMPP constructs such as IQ, Message and Presence.
It's built around a central protocol state machine (XMPPClientBase).

The state machine uses the abstract concept of a transport (XMPPTransport) to communicate with the server.
The transport encodes all aspects of the XMPP stream and XMPPStanzas enabling a flexible
abstraction for differrent underlaying communication technologies.

BOSH Transport
--------------
The BOSH Transport implements the BOSH protocol which allows for an XMPP stream over the HTTP protocol.
The transport is built around BOSH requests, managing encoding, parsing and communication. The requests
are scheduled using a scheduler to manage underlaying sockets, timeout and retries.
