1.1 Purpose

The UDP Engine plugin parses incoming Ethernet frames, identifies IPv4/UDP packets 
destined to a configurable UDP port, and generates a deterministic response packet (echo + timestamp). 
Non-matching packets are either dropped or passed through.

1.2 Operating Assumptions

   - MAC strips FCS on RX
   - MAC generates FCS on TX
   - No VLAN support (initial version)
   - Only IPv4 supported
   - No IP fragmentation supported
   - Fixed 20-byte IPv4 header (no options)
   - Only UDP supported (no TCP/ICMP handling)
   - AXI-Stream is 64-bit wide
   - TUSER=1 indicates bad frame

1.3 Functional Requirements

   - Shall parse Ethernet header (14 bytes)
   - Shall detect EtherType 0x0800
   - Shall parse IPv4 header
   - Shall verify protocol field == 17 (UDP)
   - Shall match configurable destination port
   - Shall generate response frame with:
   - Swapped MAC addresses
   - Swapped IP addresses
   - Swapped UDP ports
   - Shall append 64-bit timestamp to payload
   - Shall recompute IPv4 header checksum
   - Shall recompute UDP checksum (or set to 0 for IPv4)


Step 1 — Ethernet parser

This strips:

   Destination MAC
   Source MAC
   EtherType

And checks:

   Is EtherType = 0x0800? (IPv4)
   Only then pass payload forward.

Step 2 — IPv4 parser

This parses:

   Version / IHL
   Total Length
   Protocol field (must be 17 for UDP)
   Source IP
   Destination IP
   Only then pass payload forward.

Step 3 — UDP parser

This parses:

   Source Port
   Destination Port
   Length
   Checksum

Then pass UDP payload to your actual application logic.