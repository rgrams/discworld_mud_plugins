
-- Color conversion map (-after- inverting the image).

local map = {
-- The first three numbers are the input r,g,b and the second three are the output.
	{ 1.00, 0.48, 1.00, 0.19, 0.80, 0.19 },
	{ 0.48, 0.74, 1.00, 0.67, 0.41, 0.15 },
	{ 1.00, 0.48, 0.48, 0.00, 0.52, 0.52 },
	{ 0.00, 0.52, 0.87, 1.00, 0.48, 0.13 },
	-- Swapping red and cyan with each other...
	{ 0.00, 1.00, 1.00, 2.00, 0.00, 0.00 }, -- Cyan to super-red
	{ 1.00, 0.00, 0.00, 0.00, 1.00, 1.00 }, -- Red to cyan
	{ 2.00, 0.00, 0.00, 1.00, 0.00, 0.00 }, -- Super-red to red
	{ 1.00, 0.00, 1.00, 0.00, 0.70, 0.00 },
	{ 1.00, 1.00, 0.00, 0.33, 0.55, 0.99 },
	{ 0.00, 1.00, 0.00, 1.00, 0.30, 1.00 },
	{ 0.22, 0.22, 0.22, 0.58, 0.58, 0.58 },
	{ 0.00, 0.00, 1.00, 1.00, 0.88, 0.00 },
	{ 0.48, 0.48, 0.22, 0.43, 0.43, 0.69 },
	{ 0.00, 0.48, 0.74, 1.00, 0.52, 0.26 },
	{ 0.17, 0.00, 0.17, 0.01, 0.12, 0.00 },
	{ 1.00, 0.04, 1.00, 0.00, 0.73, 0.00 },
	{ 1.00, 0.02, 1.00, 0.00, 0.71, 0.00 },
	{ 1.00, 0.12, 1.00, 0.00, 0.81, 0.00 },
	{ 0.05, 1.00, 1.00, 1.00, 0.60, 0.60 },
	{ 0.35, 0.19, 0.03, 0.09, 0.25, 0.42 },
	{ 0.35, 0.74, 1.00, 0.96, 0.57, 0.31 },
	{ 1.00, 0.48, 0.22, 0.22, 0.73, 0.99 },
	{ 0.09, 0.22, 0.48, 0.30, 0.21, 0.00 },
	{ 1.00, 1.00, 0.48, 0.15, 0.35, 0.64 },
	{ 0.22, 0.13, 0.22, 0.11, 0.21, 0.11 },
	{ 0.74, 0.35, 0.22, 0.17, 0.56, 0.69 },
	{ 1.00, 0.74, 0.48, 0.65, 0.83, 1.00 },
	{ 0.09, 0.09, 0.48, 0.15, 0.15, 0.00 },
	{ 0.74, 0.87, 1.00, 0.95, 0.82, 0.69 },
	{ 0.09, 0.35, 0.74, 0.49, 0.29, 0.00 },
	{ 0.22, 0.09, 0.48, 0.15, 0.22, 0.00 },
	{ 0.22, 0.48, 1.00, 0.67, 0.45, 0.00 },
	{ 1.00, 1.00, 0.74, 0.97, 0.97, 1.00 },
	{ 0.35, 0.22, 0.22, 0.17, 0.30, 0.30 },
	{ 0.22, 0.22, 0.48, 0.28, 0.28, 0.02 },
	{ 0.48, 0.48, 0.74, 0.54, 0.54, 0.28 },
	{ 0.00, 0.17, 0.91, 0.25, 0.21, 0.00 },
	{ 0.48, 0.29, 0.00, 0.25, 0.45, 0.82 }, -- am_docks water
}

return map
