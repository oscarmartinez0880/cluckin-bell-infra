# Dev/QA EKS Scheduler Configuration
# Account: cluckin-bell-qa (264765154707)
# Cluster: cluckn-bell-nonprod

region       = "us-east-1"
profile      = "cluckin-bell-qa"
cluster_name = "cluckn-bell-nonprod"

# Auto-discover all managed nodegroups
nodegroups = []

# Daytime capacity (1 node per nodegroup)
scale_up_min_size     = 1
scale_up_desired_size = 1
scale_up_max_size     = 1
