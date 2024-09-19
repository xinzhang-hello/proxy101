---
layout: post
title:  "Best Practice for Spring Boot On EKS"
date:   2024-09-17 11:00:10 +0800
categories: proxy101
---
# Best Practice for Spring Boot On EKS(P1)
## Introduction
In this article, I will guide those who wants to know how a production-ready appliction works from creating code repository to deployment. Most importantly, after deploying to production environment, we need to easily monitor its status and check logs. There are many tutorials on the internet, but I will focus on best practices I have personally evaluated . 



##  Why I am writing?

1. To server a journal recording my work
2. AI typically performs well on single functions, but struggles with the entire workflow when combined.
3. Practice English writing.



## The final outcome will include such things

- A Spring Boot template repository that integrates with all the infrastructure sercices.
- Scripts required to build all the infrastructure services by default



## Principle

1. Deploy infrastructure  as much on EKS mannually
1. Whenever possible, use scripts instead of the AWS console UI



# Architecture

Before dive into every details, I will show you the full picture of our system.

## Compoents/Services

- CI/CD
  - Github
  - Jenkins
  - AWS ECR
- Monitor
  - Grafana
  - Prometheus
- Logs
  - Filebeat
  - Elasticsearch
  - Kibana
- Storage
  - Redis
  - AWS RDS(PostgreSQL)
- AWS EKS
  - ingress
- Java application
  - Web-Service
  - Other-Service
- Frontend service
  - Vue/React service

# Spring Boot repository template



