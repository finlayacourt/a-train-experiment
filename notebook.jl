### A Pluto.jl notebook ###
# v0.19.0

using Markdown
using InteractiveUtils

# ╔═╡ 613be36a-87ba-4822-aae1-736ebb13bc36
using JSON

# ╔═╡ 67a785fa-004d-4b28-ae4d-23e57807c320
using LightXML

# ╔═╡ fe8cacb6-6fc2-4feb-9f2b-a6946930d456
using Graphs

# ╔═╡ 1a3728be-e2a4-442c-9711-62f6ec87b05f
using GraphPlot

# ╔═╡ d6ac7163-e752-4a2a-9ca1-99e9cd0e670a
using Compose

# ╔═╡ e76f6189-fbe4-4691-a1a8-bafd40646611
md"# $\max(\min($changes$)$ on a train$)$"

# ╔═╡ a0a485bf-6d48-4f1e-9db8-c080e2667bb0
md"""
## Getting the data
Timetable data is updated weekly on the National Rail Data Portal.
"""

# ╔═╡ f9d4c279-7e95-4fb2-9de6-0b167f35214d
begin
	username = ""
	password = ""
end;

# ╔═╡ 9eba071a-912d-4494-b728-5c4b619d760e
# ╠═╡ disabled = true
#=╠═╡
begin
	mkpath("data")
	
	token = JSON.parse(
		read(
			`curl
			     'https://opendata.nationalrail.co.uk/authenticate' \
				 --silent \
			     --request POST \
			     --header 'Content-Type: application/x-www-form-urlencoded' \
			     --data-urlencode 'username='$username \
			     --data-urlencode 'password='$password`,
			String
		)
	)["token"]
	
	run(`curl
		'https://opendata.nationalrail.co.uk/api/staticfeeds/3.0/timetable' \
		-H 'Content-Type:\ application/json' \
		-H 'Accept: */*' \
		-H 'X-Auth-Token: '$token \
		--output data/timetable.zip \
		--silent`
	)

	run(`curl
		'https://opendata.nationalrail.co.uk/api/staticfeeds/4.0/stations' \
		-H 'Content-Type:\ application/json' \
		-H 'Accept: */*' \
		-H 'X-Auth-Token: '$token \
		--output data/stations.xml \
		--silent`
	)	
	
	run(`unzip -qo data/timetable.zip -d data`)
end;
  ╠═╡ =#

# ╔═╡ c85090c0-4bd9-4473-888d-c78996ee747f
md"""
The data feeds of intrest are
- `stations.xml`: **Stations**
- `RJTTF490.MSN`: **TIPLOCs**
- `RJTTF490.MCA`: **Timetable**
- `RJTTF490.ALF`: **Fixed links** not in the timetable (e.g. tube)
"""

# ╔═╡ 84bd0505-2c22-4220-bdc4-52fa9dda3303
md"""
### Stations
"""

# ╔═╡ 54ff9961-600f-4b23-9f67-7d90f8384d8b
begin
	crs_to_index = Dict()
	index_to_crs = Dict()
	index_to_long = Dict()
	index_to_lat = Dict()
	
	xdoc = parse_file("data/stations.xml")
	xstations = root(xdoc);
	for (index, xstation) in enumerate(get_elements_by_tagname(xstations, "Station"))
		crs = content(find_element(xstation, "CrsCode"))
		long = content(find_element(xstation, "Longitude"))
		lat = content(find_element(xstation, "Latitude"))
		crs_to_index[crs] = index
		index_to_crs[index] = crs
		index_to_long[index] = parse(Float64, long)
		index_to_lat[index] = parse(Float64, lat)
	end
end

# ╔═╡ ade54434-857c-482a-8ae3-508937973910
md"## TIPLOCs"

# ╔═╡ 4e5bfa53-70f5-4bc3-acf1-f31a53152d38
html"""
<style>
	h-s { opacity: 0.5 }

	h-r { color: red }

	h-p { color: deeppink }
	h-o { color: orange }

	h-b { color: blue }
	h-n { color: navy }

	h-g { color: green }
	h-l { color: olive }
	h-t { color: teal }
</style>
<pre>
<h-r>A</h-r>    INVERSHIN                     0<h-o>INVRSHN</h-o>INH   <h-p>INH</h-p>12580 68954 5
<h-r>A</h-r>    INVERURIE                     2<h-o>INVURIE</h-o>INR   <h-p>INR</h-p>13776 68218 5
<h-r>A</h-r>    IPSWICH                       2<h-o>IPSWICH</h-o>IPS   <h-p>IPS</h-p>16157 62438 5
<h-r>A</h-r>    IRLAM                         0<h-o>IRLAM  </h-o>IRL   <h-p>IRL</h-p>13713 63932 5
<h-r>A</h-r>    IRVINE                        0<h-o>IRVN   </h-o>IRV   <h-p>IRV</h-p>12316 66385 5
</pre>
"""

# ╔═╡ 8adc429c-57b8-4150-8071-2651a4367919
html"""
<ul>
<li>Station entries begin with <h-r>A</h-r></li>
<li>Stations have a non-unique <h-o>TIPLOC<h-o></li>
<li>Stations have a unique <h-p>CRS</h-p></li>
</ul>
"""

# ╔═╡ b4bd7d8d-9781-47da-b1f0-f4530d0c451d
begin
	tiploc_to_index = Dict()
	
	open("data/RJTTF490.MSN") do io
		i = 1
		for l in eachline(io)
			if l[1] == 'A' && l[6] != ' '
				tiploc = l[37:43]
				crs = l[50:52]
				if haskey(crs_to_index, crs)
					tiploc_to_index[tiploc] = crs_to_index[crs]
				end
			end
		end
	end
end

# ╔═╡ ab26ea17-a0ee-43eb-92b6-d7a2fc5f04fc
md"### Timetable"

# ╔═╡ 9fb1869d-e87e-40a3-a78f-f805187fbba1
md"#### Schedule"

# ╔═╡ 8c210cfc-0f1e-4788-bc95-a0e075a7b51a
html"""
<pre>
<h-r>BS</h-r>N<h-b>C00856</h-b><h-g>220515</h-g><h-l>221204</h-l>0000001 POO2D05    124627006 EMU483 045      S            P
<h-s>BX         ILYIL000000</h-s>                                                          
<h-r>LO</h-r><h-o>RYDP   </h-o> <h-t>0645 </h-t>0645          TB                                                 
<h-r>LI</h-r><h-o>RYDE   </h-o> <h-t>0646H</h-t>0647      06470647         T                                     
<h-r>LI</h-r><h-o>RYDS   </h-o> <h-t>0650 </h-t>0651      06500651         T                                     
<h-s>LISMALBRK           0653H00000000   </h-s>                                            
<h-r>LI</h-r><h-o>BRDING </h-o> <h-t>0658 </h-t>0659      06580659         T                                     
<h-r>LI</h-r><h-o>SNDOWN </h-o> <h-t>0703 </h-t>0704      07030704         T                                     
<h-r>LI</h-r><h-o>LAKEIOW</h-o> <h-t>0706H</h-t>0707H     07070707         T                                     
<h-r>LT</h-r><h-o>SHANKLN</h-o> <h-t>0710 </h-t>0710      TF   
</pre>
"""

# ╔═╡ 2094487f-d031-4864-9bf3-e9126c6d510e
html"""
<ul>
<li>Schedules begin with <h-r>BS</h-r> and end with <h-r>LT</h-r></li>
<li>Schedules uniquely defined by the <h-b>UID</h-b>, <h-g>start date</h-g> and <h-l>end date</h-l></li>
<li>Entries <h-r>LO</h-r>, <h-r>LI</h-r> and <h-r>LT</h-r> give <h-t>arrival time</h-t> at <h-o>TIPLOC</h-o></li>
</ul>
"""

# ╔═╡ 0d0259ed-3661-4f35-b452-23ee3f780649
begin
	schedules = Dict(); # UID -> index[]

	open("data/RJTTF490.MCA") do io
		leg_uid = missing
		leg_stops = []
		for l in eachline(io)
			if l[1:2] == "BS"
				leg_uid = l[4:21]
			elseif l[1:2] == "LO" || l[1:2] == "LI" || l[1:2] == "LT"
				tiploc = l[3:9]
				time = l[11:15]
				if time != "     " && haskey(tiploc_to_index, tiploc)
					push!(leg_stops, tiploc_to_index[tiploc])
				end
				if l[1:2] == "LT"
					schedules[leg_uid] = leg_stops
					leg_uid = missing
					leg_stops = []
				end
			end
		end
	end
end

# ╔═╡ 2d4bdf1d-d9d0-4a05-97d4-ca3b3fa089a7
md"#### Associations"

# ╔═╡ 88563fbc-5f36-4220-937c-f668edbf68fd
html"""
<pre>
<h-s>AANY56764Y584292209242209240000010   GLGC     T                                C</h-s>
<h-r>AA</h-r>N<h-b>Y66719</h-b><h-n>Y66849</h-n><h-g>220924</h-g><h-l>220924</h-l>0000010<h-r>JJ</h-r>SSLSBRY   TP                               O
<h-r>AA</h-r>N<h-b>Y93551</h-b><h-n>Y92100</h-n><h-g>220924</h-g><h-l>220924</h-l>0000010<h-r>JJ</h-r>SCRDFCEN  TP                               O
<h-r>AA</h-r>N<h-b>C43616</h-b><h-n>C43580</h-n><h-g>220925</h-g><h-l>220925</h-l>0000001<h-r>VV</h-r>NEDINBUR  TP                               N
<h-r>AA</h-r>N<h-b>C43616</h-b><h-n>C43623</h-n><h-g>220925</h-g><h-l>220925</h-l>0000001<h-r>VV</h-r>NEDINBUR  TP                               O
<h-s>AANL36382L364532209252209250000001   YORK     T                                C</h-s>
</pre>
"""

# ╔═╡ 8633ca5a-4744-4dcb-8e61-841feb773d71
html"""
<ul>
	<li>Two schedules are associated if a train splits, or joins another</li>
	<li>Associations begin with <h-r>AA</h-r></li>
	<li><h-n>UID2</h-n> joins (<h-r>JJ</h-r>) with or splits (<h-r>VV</h-r>) from <h-b>UID1</h-b> from <h-g>start date</h-g> to <h-l>end date</h-l></li>
</ul>
"""

# ╔═╡ 8622664d-18d4-4656-8c21-1560a3af2da2
begin
	splits = Dict(); # UID1 -> (UID2, index)
	joins = Dict(); # UID1 -> (UID2, index)

	open("data/RJTTF490.MCA") do io
		leg_uid = missing
		leg_stops = []
		for l in eachline(io)
			if l[1:2] == "AA"
				uid1 = l[4:9] * l[16:27]
				uid2 = l[10:27]
				code = l[35:36]
				tiploc = l[38:44]
				if code == "VV" && haskey(tiploc_to_index, tiploc)
					splits[uid2] = (uid1, tiploc_to_index[tiploc])
				elseif code == "JJ" && haskey(tiploc_to_index, tiploc)
					joins[uid2] = (uid1, tiploc_to_index[tiploc])
				end
			end
		end
	end
end

# ╔═╡ 297bf6d7-adfb-406a-baaf-c32a3dc977ad
md"### Fixed links"

# ╔═╡ 1c807af0-fcb0-4799-add4-3bd49d87535a
html"""
<pre>
M=WALK,O=<h-r>BDQ</h-r>,D=<h-p>BDI</h-p>,T=16,S=0001,E=2359,P=4,R=0000001
M=WALK,O=<h-r>BDQ</h-r>,D=<h-p>BDI</h-p>,T=16,S=0001,E=2359,P=4,R=1111110
M=TRANSFER,O=<h-r>BDS</h-r>,D=<h-p>LBG</h-p>,T=30,S=0001,E=0659,P=4,R=0000001
M=TRANSFER,O=<h-r>BDS</h-r>,D=<h-p>LBG</h-p>,T=30,S=0001,E=0629,P=4,R=0000010
M=TRANSFER,O=<h-r>BDS</h-r>,D=<h-p>LBG</h-p>,T=30,S=0001,E=0529,P=4,R=1111100
M=TUBE,<h-r>O=BDS</h-r>,D=<h-p>LBG</h-p>,T=25,S=0700,E=2359,P=4,R=0000001
M=TUBE,<h-r>O=BDS</h-r>,D=<h-p>LBG</h-p>,T=25,S=0630,E=0659,P=4,R=0000010
</pre>
"""

# ╔═╡ 938c6291-e9f0-4556-a508-8aa795621977
html"<p>Entry gives link from <h-r>CRS1</h-r> to <h-p>CRS2</h-p></p>"

# ╔═╡ 97d120c2-b9ba-4771-bdc2-e22a8e977a6c
begin
	fixed = []
	
	open("data/RJTTF490.ALF") do io
		for l in eachline(io)
			m = match(r"O=([A-Z]{3}),D=([A-Z]{3})", l)
			if haskey(crs_to_index, m[1]) && haskey(crs_to_index, m[2])
				push!(fixed, (crs_to_index[m[1]], crs_to_index[m[2]]))
			end
		end
	end
end

# ╔═╡ 6fa170a8-43a8-45a7-9a30-96bf8c10342e
md"## Building the graph" 

# ╔═╡ 904ceef9-1390-4b8d-af86-88344088af93
md"""
- Construct a graph of connected stations as a symmetric bit matrix
- For each schedule1 in schedules
  - Connect every station to every other station in schedule1
  - If schedule2 joins with schedule1, then connect every station in schedule2 after join to every station in schedule1
  - If schedule2 splits from schedule1, then connect every station in schedule2 before split to every station in schedule1
- For each fixed link connect the two stations
"""

# ╔═╡ cfe97f3f-1820-40df-b30e-6e7c9e386751
begin
	matrix = BitArray(undef, length(crs_to_index), length(crs_to_index))
	
	Threads.@threads for (uid, stops) in collect(schedules)
		for i in 1:length(stops)
			for j in i:length(stops)
				matrix[stops[i],stops[j]] = true
				matrix[stops[j],stops[i]] = true
			end
		end
		if haskey(joins, uid)
			uid2, crs = joins[uid]
			join_stops = schedules[uid2]
			first_join = findfirst(s -> s == crs, join_stops)
			for i in 1:length(stops)
				for j in first_join:length(join_stops)
					matrix[stops[i],join_stops[j]] = true
					matrix[join_stops[j],stops[i]] = true
				end
			end
		end
		if haskey(splits, uid)
			uid2, crs = splits[uid]
			split_stops = schedules[uid2]
			first_split = findfirst(s -> s == crs, split_stops)
			for i in 1:length(stops)
				for j in 1:first_split
					matrix[stops[i],split_stops[j]] = true
					matrix[split_stops[j],stops[i]] = true
				end
			end
		end
	end
	
	for (s1, s2) in fixed
		if any(matrix[:,s1]) && any(matrix[:,s2])
			matrix[s1, s2] = true
			matrix[s2, s1] = true
		end
	end
end

# ╔═╡ d54ad432-796c-475d-8f60-9cd84c91bec5
size(matrix)

# ╔═╡ f84745bb-9f26-4b12-9bf8-6f83b71076d4
md"If two columns of the matrix are the same, then the stations are idenitically connected and we need only consider one of them. This is equivalent to Gaussian elimination."

# ╔═╡ 0714c31c-026d-4805-941b-9ba81da59e47
function dedupe(A)
	B = copy(A)
	m,n = size(B)
	I = collect(1:n)
	# Iterate over diagonal
	r, c = 1,1
	while r <= m && c <= n
		if B[r,c] == 0
			# If non-zero below then transpose cols
			for k in c+1:n
				if B[r,k] != 0
					B[:,c], B[:,k] = B[:,k], B[:,c]
					I[c], I[k] = I[k], I[c]
					break
				end
			end
			# Otherwise skip this row
			if B[r,c] == 0
				r += 1
				continue
			end
		end

		# XOR with cols to right
		for i in c+1:n
			if B[r,i] == 1
				B[:,i] = B[:,i] .⊻ B[:,c]
			end
		end
		r += 1
		c += 1
	end
	return @view A[I[1:c-1],I[1:c-1]]
end

# ╔═╡ c30787a0-1a29-4c11-a53c-83e2c7e49415
unique = dedupe(matrix);

# ╔═╡ 950c447d-591f-4aca-a075-3b3cc9aae98f
size(unique)

# ╔═╡ 1a1cadd9-cdb3-478a-9716-4e456d5ec98f
md"## Walking the graph"

# ╔═╡ eb2ee95b-7fa9-49eb-9ec0-87414a70993b
md"
For each station, calculate the shortest path to every other station using Bellman–Ford.
"

# ╔═╡ 2f79bf28-c62e-4eba-86b5-f6ca154ffdc4
graph = Graph(unique);

# ╔═╡ f6ab9cb0-41d2-4fa1-ab11-73b3260cf608
begin
	n, = size(unique)
	stops = zeros(Int8, n, n);
	Threads.@threads for i in 1:n
		state = bellman_ford_shortest_paths(graph, i)
		for j in i:n
			stops[i,j] = length(enumerate_paths(state, j))-1
		end
	end
end

# ╔═╡ 910e4715-df4f-49ee-b184-529182c8bc3f
md"Find all shortest paths with more than 5 changes"

# ╔═╡ 27eecb55-a488-48ef-b493-3ddf71f20f60
result_to_index = parentindices(unique)[1];

# ╔═╡ 255183ad-f744-49b8-a305-25f55137f787
map(
	coords -> (
		index_to_crs[result_to_index[coords[1]]],
		index_to_crs[result_to_index[coords[2]]]
	),
	findall(i -> i > 5, stops)
)

# ╔═╡ 15f29a2b-f37a-41d5-8656-4ab5c6eacace
md"## Visulisation"

# ╔═╡ 0f285215-43c3-4e67-a467-3a10a8b78975
locs_x = map(i -> index_to_long[i], 1:length(index_to_long))

# ╔═╡ 354a3d8c-2684-4a68-a859-199bf450d58e
locs_y = map(i -> -index_to_lat[i], 1:length(index_to_lat))

# ╔═╡ d66a320b-3d30-46fb-810b-514a400e847c
long_routes_matrix = let
	ids = Set()
	for route in findall(i -> i > 5, stops)
		path = a_star(graph, route[1], route[2])
		push!(ids, path[1].src, map(p -> p.dst, path)...)
	end
	collected = collect(ids)
	@view unique[collected, collected]
end;

# ╔═╡ 2e825f81-2271-47f5-ad84-2ee674b44073
long_routes = Graph(long_routes_matrix)

# ╔═╡ bde81f3a-9c68-44ff-ae69-64110325cca8
compose(
	context(0.0w, 0.0h, 0.7w, 1.0h),
	gplot(
		long_routes,
		locs_x[parentindices(long_routes_matrix)[1]], locs_y[parentindices(long_routes_matrix)[1]],
		nodefillc = "orange",
		NODESIZE = 0.01
	)
)

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
Compose = "a81c6b42-2e10-5240-aca2-a61377ecd94b"
GraphPlot = "a2cc645c-3eea-5389-862e-a155d0052231"
Graphs = "86223c79-3864-5bf0-83f7-82e725a168b6"
JSON = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
LightXML = "9c8b4983-aa76-5018-a973-4c85ecc9e179"

[compat]
Compose = "~0.9.4"
GraphPlot = "~0.5.2"
Graphs = "~1.7.1"
JSON = "~0.21.3"
LightXML = "~0.9.0"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.7.2"
manifest_format = "2.0"

[[deps.ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"

[[deps.ArnoldiMethod]]
deps = ["LinearAlgebra", "Random", "StaticArrays"]
git-tree-sha1 = "f87e559f87a45bece9c9ed97458d3afe98b1ebb9"
uuid = "ec485272-7323-5ecc-a04f-4719b315124d"
version = "0.1.0"

[[deps.Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"

[[deps.Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"

[[deps.ColorTypes]]
deps = ["FixedPointNumbers", "Random"]
git-tree-sha1 = "eb7f0f8307f71fac7c606984ea5fb2817275d6e4"
uuid = "3da002f7-5984-5a60-b8a6-cbb66c0b333f"
version = "0.11.4"

[[deps.Colors]]
deps = ["ColorTypes", "FixedPointNumbers", "Reexport"]
git-tree-sha1 = "417b0ed7b8b838aa6ca0a87aadf1bb9eb111ce40"
uuid = "5ae59095-9a9b-59fe-a467-6f913c188581"
version = "0.12.8"

[[deps.Compat]]
deps = ["Dates", "LinearAlgebra", "UUIDs"]
git-tree-sha1 = "924cdca592bc16f14d2f7006754a621735280b74"
uuid = "34da2185-b29b-5c13-b0c7-acf172513d20"
version = "4.1.0"

[[deps.CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"

[[deps.Compose]]
deps = ["Base64", "Colors", "DataStructures", "Dates", "IterTools", "JSON", "LinearAlgebra", "Measures", "Printf", "Random", "Requires", "Statistics", "UUIDs"]
git-tree-sha1 = "d853e57661ba3a57abcdaa201f4c9917a93487a2"
uuid = "a81c6b42-2e10-5240-aca2-a61377ecd94b"
version = "0.9.4"

[[deps.DataStructures]]
deps = ["Compat", "InteractiveUtils", "OrderedCollections"]
git-tree-sha1 = "d1fff3a548102f48987a52a2e0d114fa97d730f0"
uuid = "864edb3b-99cc-5e75-8d2d-829cb0a9cfe8"
version = "0.18.13"

[[deps.Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"

[[deps.DelimitedFiles]]
deps = ["Mmap"]
uuid = "8bb1440f-4735-579b-a4ab-409b98df4dab"

[[deps.Distributed]]
deps = ["Random", "Serialization", "Sockets"]
uuid = "8ba89e20-285c-5b6f-9357-94700520ee1b"

[[deps.Downloads]]
deps = ["ArgTools", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"

[[deps.FixedPointNumbers]]
deps = ["Statistics"]
git-tree-sha1 = "335bfdceacc84c5cdf16aadc768aa5ddfc5383cc"
uuid = "53c48c17-4a7d-5ca2-90c5-79b7896eea93"
version = "0.8.4"

[[deps.GraphPlot]]
deps = ["ArnoldiMethod", "ColorTypes", "Colors", "Compose", "DelimitedFiles", "Graphs", "LinearAlgebra", "Random", "SparseArrays"]
git-tree-sha1 = "5cd479730a0cb01f880eff119e9803c13f214cab"
uuid = "a2cc645c-3eea-5389-862e-a155d0052231"
version = "0.5.2"

[[deps.Graphs]]
deps = ["ArnoldiMethod", "Compat", "DataStructures", "Distributed", "Inflate", "LinearAlgebra", "Random", "SharedArrays", "SimpleTraits", "SparseArrays", "Statistics"]
git-tree-sha1 = "db5c7e27c0d46fd824d470a3c32a4fc6c935fa96"
uuid = "86223c79-3864-5bf0-83f7-82e725a168b6"
version = "1.7.1"

[[deps.Inflate]]
git-tree-sha1 = "f5fc07d4e706b84f72d54eedcc1c13d92fb0871c"
uuid = "d25df0c9-e2be-5dd7-82c8-3ad0b3e990b9"
version = "0.1.2"

[[deps.InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"

[[deps.IterTools]]
git-tree-sha1 = "fa6287a4469f5e048d763df38279ee729fbd44e5"
uuid = "c8e1da08-722c-5040-9ed9-7db0dc04731e"
version = "1.4.0"

[[deps.JLLWrappers]]
deps = ["Preferences"]
git-tree-sha1 = "abc9885a7ca2052a736a600f7fa66209f96506e1"
uuid = "692b3bcd-3c85-4b1f-b108-f13ce0eb3210"
version = "1.4.1"

[[deps.JSON]]
deps = ["Dates", "Mmap", "Parsers", "Unicode"]
git-tree-sha1 = "3c837543ddb02250ef42f4738347454f95079d4e"
uuid = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
version = "0.21.3"

[[deps.LibCURL]]
deps = ["LibCURL_jll", "MozillaCACerts_jll"]
uuid = "b27032c2-a3e7-50c8-80cd-2d36dbcbfd21"

[[deps.LibCURL_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll", "Zlib_jll", "nghttp2_jll"]
uuid = "deac9b47-8bc7-5906-a0fe-35ac56dc84c0"

[[deps.LibGit2]]
deps = ["Base64", "NetworkOptions", "Printf", "SHA"]
uuid = "76f85450-5226-5b5a-8eaa-529ad045b433"

[[deps.LibSSH2_jll]]
deps = ["Artifacts", "Libdl", "MbedTLS_jll"]
uuid = "29816b5a-b9ab-546f-933c-edad1886dfa8"

[[deps.Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"

[[deps.Libiconv_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "42b62845d70a619f063a7da093d995ec8e15e778"
uuid = "94ce4f54-9a6c-5748-9c1c-f9c7231a4531"
version = "1.16.1+1"

[[deps.LightXML]]
deps = ["Libdl", "XML2_jll"]
git-tree-sha1 = "e129d9391168c677cd4800f5c0abb1ed8cb3794f"
uuid = "9c8b4983-aa76-5018-a973-4c85ecc9e179"
version = "0.9.0"

[[deps.LinearAlgebra]]
deps = ["Libdl", "libblastrampoline_jll"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"

[[deps.Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"

[[deps.MacroTools]]
deps = ["Markdown", "Random"]
git-tree-sha1 = "3d3e902b31198a27340d0bf00d6ac452866021cf"
uuid = "1914dd2f-81c6-5fcd-8719-6d5c9610ff09"
version = "0.5.9"

[[deps.Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"

[[deps.MbedTLS_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "c8ffd9c3-330d-5841-b78e-0817d7145fa1"

[[deps.Measures]]
git-tree-sha1 = "e498ddeee6f9fdb4551ce855a46f54dbd900245f"
uuid = "442fdcdd-2543-5da2-b0f3-8c86c306513e"
version = "0.3.1"

[[deps.Mmap]]
uuid = "a63ad114-7e13-5084-954f-fe012c677804"

[[deps.MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"

[[deps.NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"

[[deps.OpenBLAS_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "4536629a-c528-5b80-bd46-f80d51c5b363"

[[deps.OrderedCollections]]
git-tree-sha1 = "85f8e6578bf1f9ee0d11e7bb1b1456435479d47c"
uuid = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
version = "1.4.1"

[[deps.Parsers]]
deps = ["Dates"]
git-tree-sha1 = "3d5bf43e3e8b412656404ed9466f1dcbf7c50269"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.4.0"

[[deps.Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "REPL", "Random", "SHA", "Serialization", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"

[[deps.Preferences]]
deps = ["TOML"]
git-tree-sha1 = "47e5f437cc0e7ef2ce8406ce1e7e24d44915f88d"
uuid = "21216c6a-2e73-6563-6e65-726566657250"
version = "1.3.0"

[[deps.Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"

[[deps.REPL]]
deps = ["InteractiveUtils", "Markdown", "Sockets", "Unicode"]
uuid = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"

[[deps.Random]]
deps = ["SHA", "Serialization"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"

[[deps.Reexport]]
git-tree-sha1 = "45e428421666073eab6f2da5c9d310d99bb12f9b"
uuid = "189a3867-3050-52da-a836-e630ba90ab69"
version = "1.2.2"

[[deps.Requires]]
deps = ["UUIDs"]
git-tree-sha1 = "838a3a4188e2ded87a4f9f184b4b0d78a1e91cb7"
uuid = "ae029012-a4dd-5104-9daa-d747884805df"
version = "1.3.0"

[[deps.SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"

[[deps.Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"

[[deps.SharedArrays]]
deps = ["Distributed", "Mmap", "Random", "Serialization"]
uuid = "1a1011a3-84de-559e-8e89-a11a2f7dc383"

[[deps.SimpleTraits]]
deps = ["InteractiveUtils", "MacroTools"]
git-tree-sha1 = "5d7e3f4e11935503d3ecaf7186eac40602e7d231"
uuid = "699a6c99-e7fa-54fc-8d76-47d257e15c1d"
version = "0.9.4"

[[deps.Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"

[[deps.SparseArrays]]
deps = ["LinearAlgebra", "Random"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"

[[deps.StaticArrays]]
deps = ["LinearAlgebra", "Random", "StaticArraysCore", "Statistics"]
git-tree-sha1 = "23368a3313d12a2326ad0035f0db0c0966f438ef"
uuid = "90137ffa-7385-5640-81b9-e52037218182"
version = "1.5.2"

[[deps.StaticArraysCore]]
git-tree-sha1 = "66fe9eb253f910fe8cf161953880cfdaef01cdf0"
uuid = "1e83bf80-4336-4d27-bf5d-d5a4f845583c"
version = "1.0.1"

[[deps.Statistics]]
deps = ["LinearAlgebra", "SparseArrays"]
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"

[[deps.TOML]]
deps = ["Dates"]
uuid = "fa267f1f-6049-4f14-aa54-33bafae1ed76"

[[deps.Tar]]
deps = ["ArgTools", "SHA"]
uuid = "a4e569a6-e804-4fa4-b0f3-eef7a1d5b13e"

[[deps.UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"

[[deps.Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"

[[deps.XML2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libiconv_jll", "Pkg", "Zlib_jll"]
git-tree-sha1 = "58443b63fb7e465a8a7210828c91c08b92132dff"
uuid = "02c8fc9c-b97f-50b9-bbe4-9be30ff0a78a"
version = "2.9.14+0"

[[deps.Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"

[[deps.libblastrampoline_jll]]
deps = ["Artifacts", "Libdl", "OpenBLAS_jll"]
uuid = "8e850b90-86db-534c-a0d3-1478176c7d93"

[[deps.nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"

[[deps.p7zip_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"
"""

# ╔═╡ Cell order:
# ╟─e76f6189-fbe4-4691-a1a8-bafd40646611
# ╟─a0a485bf-6d48-4f1e-9db8-c080e2667bb0
# ╠═613be36a-87ba-4822-aae1-736ebb13bc36
# ╠═f9d4c279-7e95-4fb2-9de6-0b167f35214d
# ╠═9eba071a-912d-4494-b728-5c4b619d760e
# ╟─c85090c0-4bd9-4473-888d-c78996ee747f
# ╟─84bd0505-2c22-4220-bdc4-52fa9dda3303
# ╠═67a785fa-004d-4b28-ae4d-23e57807c320
# ╠═54ff9961-600f-4b23-9f67-7d90f8384d8b
# ╟─ade54434-857c-482a-8ae3-508937973910
# ╟─4e5bfa53-70f5-4bc3-acf1-f31a53152d38
# ╟─8adc429c-57b8-4150-8071-2651a4367919
# ╠═b4bd7d8d-9781-47da-b1f0-f4530d0c451d
# ╟─ab26ea17-a0ee-43eb-92b6-d7a2fc5f04fc
# ╟─9fb1869d-e87e-40a3-a78f-f805187fbba1
# ╟─8c210cfc-0f1e-4788-bc95-a0e075a7b51a
# ╟─2094487f-d031-4864-9bf3-e9126c6d510e
# ╠═0d0259ed-3661-4f35-b452-23ee3f780649
# ╟─2d4bdf1d-d9d0-4a05-97d4-ca3b3fa089a7
# ╟─88563fbc-5f36-4220-937c-f668edbf68fd
# ╟─8633ca5a-4744-4dcb-8e61-841feb773d71
# ╠═8622664d-18d4-4656-8c21-1560a3af2da2
# ╟─297bf6d7-adfb-406a-baaf-c32a3dc977ad
# ╟─1c807af0-fcb0-4799-add4-3bd49d87535a
# ╟─938c6291-e9f0-4556-a508-8aa795621977
# ╠═97d120c2-b9ba-4771-bdc2-e22a8e977a6c
# ╟─6fa170a8-43a8-45a7-9a30-96bf8c10342e
# ╟─904ceef9-1390-4b8d-af86-88344088af93
# ╠═cfe97f3f-1820-40df-b30e-6e7c9e386751
# ╠═d54ad432-796c-475d-8f60-9cd84c91bec5
# ╟─f84745bb-9f26-4b12-9bf8-6f83b71076d4
# ╠═0714c31c-026d-4805-941b-9ba81da59e47
# ╠═c30787a0-1a29-4c11-a53c-83e2c7e49415
# ╠═950c447d-591f-4aca-a075-3b3cc9aae98f
# ╟─1a1cadd9-cdb3-478a-9716-4e456d5ec98f
# ╟─eb2ee95b-7fa9-49eb-9ec0-87414a70993b
# ╠═fe8cacb6-6fc2-4feb-9f2b-a6946930d456
# ╠═2f79bf28-c62e-4eba-86b5-f6ca154ffdc4
# ╠═f6ab9cb0-41d2-4fa1-ab11-73b3260cf608
# ╟─910e4715-df4f-49ee-b184-529182c8bc3f
# ╠═27eecb55-a488-48ef-b493-3ddf71f20f60
# ╠═255183ad-f744-49b8-a305-25f55137f787
# ╟─15f29a2b-f37a-41d5-8656-4ab5c6eacace
# ╠═1a3728be-e2a4-442c-9711-62f6ec87b05f
# ╠═d6ac7163-e752-4a2a-9ca1-99e9cd0e670a
# ╠═0f285215-43c3-4e67-a467-3a10a8b78975
# ╠═354a3d8c-2684-4a68-a859-199bf450d58e
# ╠═d66a320b-3d30-46fb-810b-514a400e847c
# ╠═2e825f81-2271-47f5-ad84-2ee674b44073
# ╠═bde81f3a-9c68-44ff-ae69-64110325cca8
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
