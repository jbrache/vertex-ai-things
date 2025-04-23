# Reaching private DNS based HTTP services from Vertex

While many Vertex Pipelines can be self contained, there are use cases when the pipeline code needs to reach a private endpoint hosted in a customer VPC or in their on-prem environment.  Common examples include:

- Customer HTTP APIs
- Internal Python package repositories
- NFS shares containing datasets or configuration
- Relational or analytics databases

Enabling this connectivity is known as Network Access.

## Network Access Options

Vertex Pipelines currently supports two methods of providing Network Access.

### 1. Private Service Access

This is also known as VPC networking peering.

Underneath the hood, PSA [peers](https://cloud.google.com/vpc/docs/vpc-peering) the customer VPC with the Google tenant VPC running the pipeline job.  This allows for bi-directional communication between the VPCs but comes with some drawbacks.

1. Large blocks of internal IPs must be allocated to set up PSA.  This can be challenging for organizations with complex networks.  It is common for bigger organizations to be at the point of RFC1918 exhaustion.

2. There is a limit to the number of peers a VPC may have.

3. Transitive routing is not supported via VPC peering.  Specifically, given three VPCs peered as such: VPC1<->VPC2<->VPC3, VPC1 cannot reach services in VPC3 and visa versa.  This can lead to limitations in which services Vertex can reach in enterprise VPC topologies.

### 2. Private Service Connect Interfaces

The Vertex PSC-I builds on top of the underlying [PSC-I](https://cloud.google.com/vpc/docs/about-private-service-connect-interfaces) service.  In short, PSC-I allows a VM in an entirely different org to attach a NIC to the customer (consumer) VPC.

![](https://cloud.google.com/static/vpc/images/psc-interfaces/interface-overview.svg)

Though PSC-I is a bidirectional network technology, the Vertex implmentation only facilitates *egress* from Vertex Pipelines to customer networks.

PSC-I based network access addresses all of the previously mentioned challenges with PSA:

1. Only requires small IP block allocations - typically a /28 per region.
2. The interface attachments can scale substantially higher than the limit of VPC Peers.
3. Transitive connectivity is supported such that any services the customer/consumer VPC can reach through interconnect, VPN or peering are also reachable by Vertex pipelines.

However, unlike PSA, PSC-I network access currently does not support resolving DNS records from private or internal DNS servers on the customer VPC.  This can lead to challenges reaching HTTP based services which may have a dynamic IP address or rely on HTTP host headers to route traffic correctly.

## Workaround

The problem presented by PSC-I's current limitation is not novel.  At an abstract level, the issue is communicating between two discontiguous networks where the client can only take a narrow path into the service network.  Resources inside the service network are able to reach anything with network line of sight, including DNS.

If Vertex had a way to ask a server to perform a DNS lookup and connection on _behalf_ of the client, we'd have way forward.  Fortunately, this is exactly what [proxy servers](https://en.wikipedia.org/wiki/Proxy_server) do!

In particular, this scenario can be handled by a forward proxy.  Two commonly used forward proxies are [tinyproxy](https://tinyproxy.github.io/) and [squid](https://www.squid-cache.org/).

### HTTP Forward Proxy





## Deployment
