# Sales Engineer Take-Home Exercise 

This is my code repository for the Sales Engineer Take-Home Exercise, this includes all of the below pre-requisite code for deploying and configuring the infrastrucutre for hosting CockroachDB.

The Terraform will provision 3 EC2 instances, deploy a Network Loadbalancer, deploy a 3 node RKE Cluster, create a kubeconfig file, deploy the AWS EBS CSI Driver to enable persistant storage using GP3, deploy CertManager and finally create a Cluster Issuer for LetsEncrypt certificates.

## Pre-Requisites

- Terraform CLI
- AWS Account with IAM Instance profile for RKE/Rancher permissions
- Kubectl

## Code

### Automated
- 3 Node Kubernetes Cluster (Includes provisioning of VMs)
- Network LoadBalancer (For Ingress)
- Cert-Manager with Lets-Encrypt Issuer (For Ingress)
- AWS EBS CSI Driver (For GP3 Storage)


## Deployment Instructions

Deploy the infrastructue

```
1. Terraform apply -auto-approve
```
Configure Kubectl to point to the K8s cluster

```
2. export KUBECONFIG=kube_config_cluster.yml
```

Deploy the CRDB CRD's

```
3. kubectl apply -f operator-manifests/crds.yaml
```

Deploy the CockroachDB operator

```
4. kubectl apply -f operator-manifests/operator.yaml
```

Set current namespace to cockroach-operator-system

```
5. kubectl config set-context --current --namespace=cockroach-operator-system
```

Deploy CockroachDB Cluster (With TLS Ingress enabled)

```
6. kubectl apply -f operator-manifests/example.yaml
```
Verify Cluster Deployed Successfully
```
7. kubectl get pods
NAME                                         READY   STATUS    RESTARTS   AGE
cockroach-operator-manager-8db7c4d44-xzhlx   1/1     Running   0          58m
cockroachdb-0                                1/1     Running   0          45m
cockroachdb-1                                1/1     Running   0          45m
cockroachdb-2                                1/1     Running   0          45m
```

Access the CockroachDB UI at https://db.k8s.ds.ps.rancher.space

![Alt text](images/homepage.jpg?raw=true "CockroachDB")

Deployment Complete!


## Database Creation

First we need to deploy a Pod with the CockroachDB SQL Client installed

```
kubectl apply -f task-manifests/client-secure-operator.yaml
```

Now exec in to the pod and connect to the DB via the Kubernetes Service

```
kubectl exec -it cockroachdb-client-secure \
-- ./cockroach sql \
--certs-dir=/cockroach/cockroach-certs \
--host=cockroachdb-public
```
Create the database

```
CREATE DATABASE bank;
```
```
CREATE TABLE bank.accounts (id INT PRIMARY KEY, balance DECIMAL);
```
```
INSERT INTO bank.accounts VALUES (1, 1000.50);
```
```
SELECT * FROM bank.accounts;
```

Create a user with a password

```
CREATE USER roach WITH PASSWORD 'Q7gc8rEdS';
```
#I have add the below in as the CLI seems to always want password auth for user root even with secure flag set and certs in right directory.
```
GRANT admin TO roach;
```
Exit the SQL Client

```
\q
```

## Running a test workload

As I am using Kubernetes I will use the Service Hostname of Cockroach within the cluster which will act as the LoadBalancer for this exercise.

```
kubectl get svc

NAME                                 TYPE           CLUSTER-IP     EXTERNAL-IP                                                               PORT(S)                                          AGE
cockroach-operator-webhook-service   ClusterIP      10.43.57.229   <none>                                                                    443/TCP                                          72m
cockroachdb                          ClusterIP      None           <none>                                                                    26258/TCP,8080/TCP,26257/TCP                     59m
cockroachdb-public                   ClusterIP      10.43.72.199   <none>                                                                    26258/TCP,8080/TCP,26257/TCP                     59m
```

```
kubectl exec -it cockroachdb-client-secure -- ./cockroach workload init bank \
'postgresql://roach:Q7gc8rEdS@cockroachdb-public:26257'
```

Tolerate errors flag will prevent errors from stopping the tests from running.
```
kubectl exec -it cockroachdb-client-secure -- ./cockroach workload run bank \
--duration=60m \
--tolerate-errors \
'postgresql://roach:Q7gc8rEdS@cockroachdb-public:26257'
```


### Exercises

Scalling test (Attach a 4th Node to the cluster) - As I am using the operator I must edit the operator.yaml and re-apply it rather than kubectl scale. (kubectl patch could possibly be used here)
```
kubectl apply -f operator-manifests/example-scaled-up.yaml
```

Observations: The total node count within the UI went from 3 to 4 which was to be expected when brining in an additional node, it starts off with 0 replicas which is also to be expected. When obersving the Metrics page some more interesting things were noticeable, the P99 latency had increased by a few milliseconds and the general performance had gone down in the SQL statements chart, which over time the performance started to come back to higher levels. My assumption is this initial impact to performance is based on replicating the data across the nodes and sorting everything out.

![Alt text](images/overview-scaled-up.jpg?raw=true "ScaleOverview")  ![Alt text](images/metrics-scaled-up.jpg?raw=true "ScaleMetrics")


Gracefully remove a node from the Cluster

```
kubectl exec -it cockroachdb-client-secure -- cockroach node decommission 4 \
--certs-dir=/cockroach/cockroach-certs \
--host=cockroachdb-3.cockroachdb.cockroach-operator-system:26258
```

Observations: Immediately, performance hit within the Metrics page, the statuses on the left change and 1 node is in a suspect state. On the Overview page, the 4th node goes in to a decomissioning state and is eventually removed from the page & cluster. After decomissioning, the cluster performance is actually higher than it was with the 4th node in service, the P99 latency appears to be lower and the SQL statements appear to be higher, I was expecting performance to drop to the same level as when initially deployed.

![Alt text](images/scale-down-1.jpg?raw=true "ScaleDown1")  ![Alt text](images/scale-down-2.jpg?raw=true "ScaleDown2")


Forcibly remove a node from the cluster (think kill -9) and see how the system behaves compared to gracefully shutting down (watch for 5 minutes)

```
kubectl delete pods cockroachdb-2 --force --grace-period=0
```

Observations: Similar to gracefully terminating an instance, a suspect instance came in to the summary on the metrics page, but within 10 seconds or so the pod came back in to service and everything resumed as normal. This behaviour was expected using the operator, if I was using the standard statefulset or helm chart I could have scaled to 2. I also noticed other metrics change slightly during the recovery process such as a spike in the ranges chart.


![Alt text](images/force-delete.jpg?raw=true "ForceDel") ![Alt text](images/ranges.jpg?raw=true "ForceDel2")

Remove all nodes but one from the cluster

As I am using the operator there is a minimum of 3 nodes set within the resource definition, so I was unable to test this via kubectl scaling, however I was able to destructively delete 2 of the nodes at the same time

```
kubectl delete pods cockroachdb-1 cockroachdb-2
```

Obersvations, cluster went completely unresponsive for about 30 seconds, but then recovered. My expectation is that if I was able to scale the statefulset to 1 replica the database would not function as it would not be able to form quorum.

![Alt text](images/1-node.jpg?raw=true "1 Node")


### Executing a Code Example

The code example I have chosen to deploy is - https://www.cockroachlabs.com/docs/cockroachcloud/quickstart?filters=go

Create a Go Pod for executing code example

```
kubectl run -i -t go-pod --image=golang --restart=Never
```
```
git clone https://github.com/cockroachdb/quickstart-code-samples
```
```
cd quickstart-code-samples/go
```
```
export DATABASE_URL="postgresql://roach:Q7gc8rEdS@cockroachdb-public:26257"
```
```
go mod init basic-sample && go mod tid
```
```
go run main.go
```

![Alt text](images/hello-world.jpg?raw=true "Hello World")


### Potential Extra Credit

1. Accessible Ingress via Route53, NLB & K8s Ingress controller, certified with lets encrypt.
2. Demonstration of IaaC knowledge
3. K8s Deployment


## Additional Exercise Findings/Lessons Learnt


1. The Helm Chart deployment method doesn't work (At least for me) The self signer runs but doesn't create the root ca/keys for authenticating, documents still tell you to deploy client-secure which generates a k8s CSR which then doesn't match up for the root user. x509 error. Bringing your own certs, although the docs say when enabled will stop the init container, it didn't so I ended up with 2 lots of certs and the DB initialised with the wrong ones. 
2. Cockroach Workload command, always demands password auth even when certs dir is in place and sslmode require is set.


# Sales Engineer Take-Home Exercise Instructions
v2.0

Thank you for being interested in a position at Cockroach Labs!  As a part of our interview process, we like to have candidates get their hands dirty with the product.  This allows you to get a feel for what it’s like to work with our platform, and it gives us an opportunity to determine where best you will fit in the organization.

You can spend as much time as you’d like working on this exercise, but if you haven’t been able to get through the core portion of it in 2-4 hours please let us know.  The extra credit is just that, EXTRA, so don’t feel like you need to do any or all of it.  But successful Roachers tend to go above and beyond in at least one area. Don’t feel like it needs to be one of our suggestions though - be creative!

## High-Level Goals 

### Core:

- Demonstrate a fundamental understanding of how to launch and initialize the database
- Monitor the database during certain common scenarios as described below
- Take one of the code examples from our website and get it working against your local environment
- Present your findings back to the team

### Extra Credit (examples):

- Demonstrate a complex failure scenario and how the database manages resilience (K8s, multi-cloud, multi-dc, etc)
- Integrate a 3rd party application of your choice (a BI dashboard, an ETL tool, Monitoring etc) 
- Build an app in the language of your choice that uses CRDB as the backend (particularly one not covered by our docs)
- Anything else you think would highlight your unique skill-set
- Other ideas for extra credit are included in-line below

## Prerequisites

- Machine with at least 4 cores and 8 GB of RAM
- If running on Windows, you may want to start with a Linux VM with the same specs

If you don’t have a machine that meets these minimum requirements, please let us know and we will spin up a cloud instance on your behalf

It might also be worth going through at least some of our online tutorials before getting started with this exercise.

## Core Exercise

### Launch and Initialize CRDB

- Follow the instructions on our website to start a local cluster of 3 nodes (https://www.cockroachlabs.com/docs/stable/start-a-local-cluster.html). 
  - *Extra Credit* Launch the cluster in Docker or Kubernetes
-Connect to the Admin UI on port 8080 and verify that you can see all 3 nodes
- Set up load balancing in front of the cluster for HA (our default is HAProxy but you can use anything you’d like)

### Generate a load against the cluster

- Generate some load against the cluster - easiest way to do this is using the cockroach workload command (https://www.cockroachlabs.com/docs/stable/cockroach-workload.html)
  - You’ll want to route this through the load balancer for a later part of the exercise
  - *Extra Credit* generate some load some other way against the cluster
- Set your load generator to run for at least 60 minutes to give you time to run through some common scenarios listed below

### Scaling and Failing

#### While loading data into the cluster:
- Attach a 4th node and see how the system behaves (watch for 5 minutes)
- Gracefully remove a node from the cluster and see how the system behaves (watch for 5 minutes)
- Forcibly remove a node from the cluster (think kill -9) and see how the system behaves (watch for 5 minutes)
- Remove all nodes but one from the cluster

#### Questions to answer:
- As you were adding and removing nodes from the cluster, how did that impact performance?  What kinds of metrics were you tracking to identify that impact?
- What other kinds of behavior did you witness as you were changing the cluster topology?  How did the system handle the hard node failure differently than the graceful shutdown?
- When you killed all of the nodes but one, what happened to the database?
- Did the platform behave differently than you would expect in any of the above scenarios?  If so please describe.

### Executing a Code Example

- Shut down the load generator
- Scale the database back to at least 3 nodes and execute one of the code examples in the language of your choice (https://www.cockroachlabs.com/docs/stable/hello-world-example-apps.html).
  - *Extra Credit* Enhance the example to do more than what is demonstrated

### Present Your Findings

At a minimum, please cover the following topics:
- Describe the experience of installing and monitoring CRDB and the pros/cons to the approach you took
- Describe your understanding of the pros and cons of CRDB’s distributed architecture
- Scaling and Failing - present your answers to the questions above and any other notes on your experience
- Demonstrate your working code example
- Present any extra credit activities that highlight your unique skills

The format of the presentation should be in alignment with the role for which you’re interviewing.  That may be some form of a live demo, a presentation, or something completely different.  This is your chance to differentiate yourself.


## Appendix
### Useful Links

- Documentation - https://www.cockroachlabs.com/docs/stable/
- Tutorials - https://www.cockroachlabs.com/docs/stable/training/
- GitHub - https://github.com/cockroachdb
- Cockroach University: https://university.cockroachlabs.com/
