Position(env::GoEnv; args...) = GoPosition(env; args...)
Go(n) = GoEnv(n)

Position(env::ChessEnv; args...) = ChessPosition(env; args...)
chess(n) = ChessEnv(n)
