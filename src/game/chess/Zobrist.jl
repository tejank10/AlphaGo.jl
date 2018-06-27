# zobrist.jl

immutable ZobristHash
	hashtable::Array{UInt64,2}  # 12 pieces by 64 squares
	# TODO: add castling_rights
	# TODO: add enpassant option

	function ZobristHash(seed=0)
		# if no seed, MersenneTwister() internally uses 0
		rng = MersenneTwister(seed)
		new([rand(rng, UInt64) for i in 1:12, j in 1:64])
	end
end

@inline function update_hash(z::ZobristHash, hash::UInt64, piece::UInt8, position::UInt8)
	# XOR looked up pre-determined random number with the input hash
	z.hashtable[piece, position] ⊻ hash
end
