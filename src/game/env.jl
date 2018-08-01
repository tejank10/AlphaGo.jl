Position(env::GoEnv; args...) = GoPosition(env; args...)
Go(n) = GoEnv(n)

Position(env::GomokuEnv; args...) = GomokuPosition(env; args...)
