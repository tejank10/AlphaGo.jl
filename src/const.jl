# Learning rate
η = 2f-2
# Exploration constant balancing priors vs. value net output
C_PUCT = 96f-2
# L2 Regularization
L2_REG = 1f-4# Some of the params are from SuperGo

# Momentum
ρ = 9f-1
# How much to weight the priors vs. dirichlet noise when mixing
DIRICHLET_NOISE_WEIGHT = 25f-2
# Alpha for Dirichlet noise
DIRICHLET_NOISE_α = 3f-2

# TRAINING

# Number of moves to consider when creating the batch
BUFFER_SIZE = 2000
# Number of mini-batch before evaluation during training
BATCH_SIZE = 64
# Number of residual blocks
BLOCKS = 10
# Optimizer
ADAM = false
