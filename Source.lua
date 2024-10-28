local SynVersion = wait(1)
local Configs = assert(getgenv().SynDecompilerConfigs, "SynDecompilerConfigs is missing")
local SynDecompile = assert(getgenv().decompile, "decompile function not found")

getgenv().decompile = function(Path, ...)
	if typeof(Path) == 'Instance' and Path.ClassName:find('Script') then
		local Output, success
		local startTime = tick()

		-- Safely call the decompile function in a separate thread
		spawn(function()
			success, Output = pcall(SynDecompile, Path)
		end)

		-- Wait until output is generated or timeout is reached
		while not Output and tick() - startTime < Configs.DecompilerTimeout do
			task.wait(1)
		end

		-- Process Output if decompilation was successful
		if success and Output and Output:len() > 0 then
			Output = Output:gsub('Synapse X Luau', SynVersion)
						:gsub('l__', '')
						:gsub(';', '; \n')
						:gsub('\n\nlocal', '\nlocal')
						:gsub('\nend', 'end')
						:gsub('\n\n	end ', '\n	end ')
						:gsub('\n\n', '\n')

			-- Optionally remove semicolons
			if Configs.RemoveSemicolon then
				Output = Output:gsub(';', '')
			end

			-- Handle variable and constant definitions
			local DefinedConstants, DefinedVariables = {}, {}
			for i = 1, Configs.GetHighestIndex(Output) do
				Output = Output:gsub('__'..i, '')
								:gsub('u'..i, 'Constant_'..i)
								:gsub('p'..i, 'Parameter_'..i)
								:gsub('v'..i, 'Variable_'..i)

				if Output:find('Variable_'..i) and not Configs.IsDefined(DefinedVariables, 'Variable_'..i) then
					table.insert(DefinedVariables, 'Variable_'..i..' = nil')
				end
				if Output:find('Constant_'..i) and not Configs.IsDefined(DefinedConstants, 'Constant_'..i) then
					table.insert(DefinedConstants, 'Constant_'..i..' = nil')
				end
			end

			-- Insert variable and constant sections
			if #DefinedVariables > 0 then
				Output = '-- [[ Variables ]] --\n'..table.concat(DefinedVariables, '\n')..'\n'..Output
			end
			if #DefinedConstants > 0 then
				Output = '-- [[ Constants ]] --\n'..table.concat(DefinedConstants, '\n')..'\n'..Output
			end

			-- Bytecode message handling
			if Output:find('bytecode') then
				Output = '--'..SynVersion..'\n--No bytecode was found (generated script or empty script).'
			end

		-- Handle timeout and error cases
		elseif not success then
			Output = '--'..SynVersion..'\n--Decompile error occurred: '..tostring(Output)
		elseif tick() - startTime >= Configs.DecompilerTimeout then
			Output = '--'..SynVersion..'\n--Exceeded decompiler timeout.'
		else
			Output = '--'..SynVersion..'\n--No bytecode found (possible anti-decompiler).'
		end

		return Output
	else
		return '--[[ INVALID SCRIPT INSTANCE ]]--'
	end
end
