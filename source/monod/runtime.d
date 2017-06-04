/**
 * Interface to the Mono runtime, including initialisation.
 * 
 * License:
 * 
 * Boost Software License - Version 1.0 - August 17th, 2003
 * Permission is hereby granted,free of charge,to any person or organization
 * obtaining a copy of the software and accompanying documentation covered by
 * this license (the "Software") to use,reproduce,display,distribute,
 * execute,and transmit the Software,and to prepare derivative works of the
 * Software,and to permit third-parties to whom the Software is furnished to
 * do so,all subject to the following:
 * 
 * The copyright notices in the Software and this entire statement,including
 * the above license grant,this restriction and the following disclaimer,
 * must be included in all copies of the Software,in whole or in part,and
 * all derivative works of the Software,unless such copies or derivative
 * works are solely in the form of machine-executable object code generated by
 * a source language processor.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS",WITHOUT WARRANTY OF ANY KIND,EXPRESS OR
 * IMPLIED,INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE,TITLE AND NON-INFRINGEMENT. IN NO EVENT
 * SHALL THE COPYRIGHT HOLDERS OR ANYONE DISTRIBUTING THE SOFTWARE BE LIABLE
 * FOR ANY DAMAGES OR OTHER LIABILITY,WHETHER IN CONTRACT,TORT OR OTHERWISE,
 * ARISING FROM,OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 */
module monod.runtime;

import derelict.mono.mono;
import std.string, std.array, std.algorithm;
import core.stdc.string;

/// Interface to the Mono runtime
struct Mono
{
	private __gshared
	{
		bool initialised;
		MonoDomain* mDomain;
		string mVersion;
	}
	public __gshared
	{
		/// Custom library name to load the Mono runtime from, setup before calling initialise() if necessary.
		/// Applies only if the dynamic variant of binding is used (Mono_Dynamic version).
		string customLibNames;

		/// Custom path to Mono XML configuration file, setup before calling initialise() if necessary.
		string customMonoConfig;

		/// Custom directory for the assemblies, setup before calling initialise() if necessary.
		string customAssemblyDir;

		/// Custom directory for the Mono runtime configuration, setup before calling initialise() if necessary.
		string customConfigDir;
	}
	shared static ~this()
	{
		if (Mono.initialised)
		{
			mono_jit_cleanup(mDomain);
		}
	}

static:
	/**
	 * Initialises the Mono runtime.
	 * Params:
	 *  appName = The application name, used as Mono domain name.
	 *  cmdArgs = The commandline arguments passed to the program, that will be given to Mono.
	 */
	void initialise(string appName, string[] cmdArgs)
	{
		if (initialised)
			return;
		scope (success)
			initialised = true;

		version (Mono_Dynamic)
		{
			if (customLibNames.length)
				DerelictMono.load(customLibNames);
			DerelictMono.load;
		}

		if (customMonoConfig.length)
			mono_config_parse(customMonoConfig.toStringz);
		else
			mono_config_parse(null);

		mDomain = mono_jit_init(appName.ptr);

		// Mono wants the executed assembly as the first argument.
		if (cmdArgs.length == 0)
			cmdArgs = [appName];

		mono_runtime_set_main_args(cast(int) cmdArgs.length,
				cast(char**) cmdArgs.map!toStringz.array.ptr);

		const(char)* aDir = customAssemblyDir.length ? customAssemblyDir.toStringz : null;
		const(char)* cDir = customConfigDir.length ? customConfigDir.toStringz : null;
		if (aDir !is null || cDir !is null)
		{
			mono_set_dirs(aDir, cDir);
		}
		char* monover = mono_get_runtime_build_info();
		scope (exit)
			mono_free(monover);
		mVersion = monover[0 .. strlen(monover)].idup;
	}

	/// Returns: a string identifying the Mono runtime version.
	string getRuntimeVersionInfo() nothrow @nogc @trusted
	{
		return mVersion;
	}
}

version (unittest)
{
	/// Initialises the runtime when doing unit tests.
	shared static this()
	{
		import std.stdio : writefln;
		import monod.runtime : Mono;

		Mono.initialise("monod-testing", ["monod-testing", "--test", "--unittest"]);
		writefln("Mono runtime version %s initialised.", Mono.getRuntimeVersionInfo());
	}
}
