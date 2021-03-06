/**
 * Generator of C# code used for making D interfaces available in Mono.
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
module monobound.mgenerator;

import derelict.mono.mono;
import std.string, std.array, std.algorithm;
import std.traits, std.meta, std.functional;
import std.format, std.conv, std.stdio : writefln;
import std.range, std.uni, std.utf, std.path;
import std.file : write, isFile, isDir, exists, mkdir, mkdirRecurse, readText;
import monobound.utils;
import monobound.attributes;

/// Contains the generated code.
struct GeneratedCode
{
	/// Name of the bound module.
	string moduleName;
	/// Camel-cased module name without dots.
	string camelModuleName;

	/// The C# code.
	string csc;
	/// The indentation level.
	int cscIndent;

	/// The D code.
	string dc;
	/// The indentation level.
	int dcIndent;

	/// Appends C# code
	void cs(string a, int indent = 0)
	{
		if (indent < 0)
		{
			cscIndent += indent;
			if (cscIndent < 0)
				cscIndent = 0;
		}
		foreach (i; 0 .. cscIndent)
			csc ~= '\t';
		csc ~= a;
		csc ~= '\n';
		if (indent > 0)
		{
			cscIndent += indent;
			if (cscIndent < 0)
				cscIndent = 0;
		}
	}

	/// Appends D code
	void d(string a, int indent = 0)
	{
		if (indent < 0)
		{
			dcIndent += indent;
			if (dcIndent < 0)
				dcIndent = 0;
		}
		foreach (i; 0 .. dcIndent)
			dc ~= '\t';
		dc ~= a;
		dc ~= '\n';
		if (indent > 0)
		{
			dcIndent += indent;
			if (dcIndent < 0)
				dcIndent = 0;
		}
	}
}

private string camelDots(string dotted, bool initial = true)
{
	string result;
	bool up = initial;
	foreach (chr; dotted)
	{
		if (chr == '.')
		{
			up = true;
		}
		else
		{
			if (up)
				result ~= toUpper(chr);
			else
				result ~= chr;
			up = false;
		}
	}
	return result;
}

/**
 * Generates the binding code for a single module and saves it to C# and D files.
 * Params:
 *  M           = the module to bind
 *  autoBindAll = Whether to bind all public and bindable entities
 *                in the module, regardless of the attributes.
 *
 *  dPath       = path to the root of D sources
 *  csPath      = path to the root of C# sources
 */
GeneratedCode saveModuleToFile(alias M, bool autoBindAll = false)(string dRoot, string csRoot)
{
	dRoot ~= "/monobind";
	csRoot ~= "/MonoBind";
	immutable code = bindModule!(M, autoBindAll)();
	if (!exists(dRoot) && isDir(buildNormalizedPath(dRoot, "..")))
	{
		mkdir(dRoot);
	}
	else if (!isDir(dRoot))
	{
		throw new Exception(dRoot ~ " is not a valid directory for D sources!");
	}
	if (!exists(csRoot) && isDir(buildNormalizedPath(csRoot, "..")))
	{
		mkdir(csRoot);
	}
	else if (!isDir(csRoot))
	{
		throw new Exception(csRoot ~ " is not a valid directory for C# sources!");
	}
	string dPath = buildNormalizedPath(dRoot, code.moduleName.replace(".", "/") ~ ".d");
	string csPath = buildNormalizedPath(csRoot, code.moduleName.replace(".", "/") ~ ".cs");
	string dFolder = dirName(dPath);
	if (!isDir(dFolder))
		mkdirRecurse(dFolder);
	string csFolder = dirName(csPath);
	if (!isDir(csFolder))
		mkdirRecurse(csFolder);
	bool doDWrite = true, doCSWrite = true;
	if (exists(dPath) && isFile(dPath))
	{
		string readcode = readText(dPath);
		if (readcode == code.dc)
			doDWrite = false;
	}
	if (exists(dPath) && isFile(csPath))
	{
		string readcode = readText(csPath);
		if (readcode == code.csc)
			doCSWrite = false;
	}
	if (doDWrite)
	{
		writefln("D : %s", dPath);
		write(dPath, code.dc);
	}
	else
	{
		writefln("NC: %s", dPath);
	}
	if (doCSWrite)
	{
		writefln("C#: %s", csPath);
		write(csPath, code.csc);
	}
	else
	{
		writefln("NC: %s", csPath);
	}
	writefln("---------- done: %s", code.moduleName);
	return code;
}

/**
 * Generates the binding code for a single module.
 * Params:
 *  M           = the module to bind
 *  autoBindAll = Whether to bind all public and bindable entities
 *                in the module, regardless of the attributes.
 */
GeneratedCode bindModule(alias M, bool autoBindAll = false)()
{
	GeneratedCode code;
	code.moduleName = moduleName!M;
	code.camelModuleName = camelDots(code.moduleName, true);
	code.csc = CsPrelude.replace("@MOD@", code.moduleName).replace("@IDMOD@", code.camelModuleName);
	code.cscIndent = 1;
	code.dc = DPrelude.replace("@MOD@", code.moduleName).replace("@IDMOD@", code.camelModuleName);
	code.dcIndent = 1;

	bindFreeMembers!(M, autoBindAll)(&code);
	bindAggregates!(M, autoBindAll)(&code);

	code.csc ~= CsEpilogue;
	code.dc ~= DEpilogue;
	return code;
}

private enum string DPrelude = `/// Automatically generated D->Mono bindings for module @MOD@
module monobind.@MOD@;
import monobound.utils;
import monobound.runtime;
static import @MOD@;

/// Binds @MOD@ internal calls to the Mono runtime.
void bindToMono_@IDMOD@()
{
`;
private enum string DEpilogue = `
}`;

private enum string CsPrelude = `// Automatically generated D->Mono bindings for module @MOD@
using System;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;

namespace MonoBind {
`;
private enum string CsEpilogue = `}`;

private void bindFreeMembers(alias M, bool autoBindAll)(GeneratedCode* C)
{
	C.cs("class " ~ C.camelModuleName);
	C.cs("{", 1);
	scope (exit)
		C.cs("}", -1);
	foreach (symnm; __traits(allMembers, M))
	{
		alias sym = Alias!(__traits(getMember, M, symnm));
		static if (is(typeof(sym)) && !isAggregateType!(typeof(sym)))
		{
			alias UDAs = getUDAs!(sym, MonoBind);
			static assert(UDAs.length < 2, sym ~ " cannot have >1 MonoBind attribute!");
			static if (autoBindAll || UDAs.length == 1)
			{
				static if (isFunction!sym)
				{
					foreach (ovl; __traits(getOverloads, M, symnm))
						bindFunction!(ovl)(C);
				}
			}
		}
	}
}

private void bindAggregates(alias M, bool autoBindAll)(GeneratedCode* C)
{
	foreach (sym; __traits(allMembers, M))
	{
		static if (is(typeof(sym)) && isAggregateType!(typeof(sym)))
		{
			alias SymT = typeof(sym);
		}
	}
}

private void bindFunction(alias F)(GeneratedCode* C)
{
	string CSReturn;
	string CSMName;
	string CSName;
	string[] CSArgs;
	string[] RTArgs;

	CSName = RenamedIdOf!F;
	CSMName = "monobound" ~ F.mangleof;
	alias RetT = ReturnType!F;
	enum bool ReturnsValue = !is(RetT == void);
	alias RetTi = MonoboundTypeInfo!(RetT, BoundTypeContext.FunctionList);
	CSReturn = RetTi.csTypeName;
	alias PNames = ParameterIdentifierTuple!F;
	foreach (i, arg; Parameters!F)
	{
		alias Ti = MonoboundTypeInfo!(arg, BoundTypeContext.FunctionList);
		CSArgs ~= Ti.csTypeName ~ " " ~ PNames[i];
		RTArgs ~= Ti.drtTypeName ~ " " ~ PNames[i];
	}

	// C# stub

	C.cs("[MethodImplAttribute(MethodImplOptions.InternalCall)]");
	C.cs(format!"private extern static %s %s (%-(%s, %));"(CSReturn, CSMName, CSArgs));

	C.cs(format!"public static %s %s (%-(%s, %))"(CSReturn, CSName, CSArgs));
	C.cs("{", 1);
	C.cs(format!"%s%s(%-(%s, %));"(is(RetT == void) ? "" : "return ", CSMName, only(PNames)));
	C.cs("}", -1);

	// D function
	string RTRet = RetTi.drtTypeName;
	string FQN = fullyQualifiedName!F;
	C.d(format!"extern(C) %s %s(%-(%s, %)) nothrow"(RTRet, CSMName, RTArgs));
	C.d("{try{", 2);
	// parameter setup
	string argsStr;
	foreach (argi, argt; Parameters!F)
	{
		alias Ti = MonoboundTypeInfo!(argt, BoundTypeContext.FunctionList);
		static if (Ti.isPrimitive)
		{
			argsStr ~= PNames[argi] ~ ", ";
		}
		else
		{
			argsStr ~= format!"MonoboundTypeInfo!(%s, BoundTypeContext.FunctionList).unwrapToD(%s), "(
					fullyQualifiedName!argt, PNames[argi]);
			C.d(format!"MonoboundTypeInfo!(%s, BoundTypeContext.FunctionList).beginUse(%s);"(
					fullyQualifiedName!argt, PNames[argi]));
		}
	}

	// remove the last ", "
	if (argsStr.length > 2)
		argsStr = argsStr[0 .. $ - 2];

	// call and return boxing
	static if (ReturnsValue)
	{
		C.d(format!"%s __monobound_retval = MonoboundTypeInfo!(%s, BoundTypeContext.FunctionList).wrapForMono(%s(%s));"(
				RetTi.drtTypeName, fullyQualifiedName!RetT, FQN, argsStr));
	}
	else
	{
		C.d(format!"%s(%s);"(FQN, argsStr));
	}

	// parameter destruction
	foreach (argi, argt; Parameters!F)
	{
		alias Ti = MonoboundTypeInfo!(argt, BoundTypeContext.FunctionList);
		static if (!Ti.isPrimitive)
		{
			C.d(format!"MonoboundTypeInfo!(%s, BoundTypeContext.FunctionList).endUse(%s);"(
				fullyQualifiedName!argt,
				PNames[argi]));
		}
	}

	// actual return
	static if (ReturnsValue)
	{
		C.d("return __monobound_retval;");
	}

	C.d("}", -1);
	C.d("catch(Throwable t)");
	C.d("{", 1);
	// TODO:Exception translation
	if (!is(RetT == void))
	{
		C.d("return " ~ RTRet ~ ".init;");
	}
	C.d("}}", -2);
	C.d(format!`Mono.addInternalCall("%s", &%s);`("MonoBind." ~ C.camelModuleName ~ "::" ~ CSMName, CSMName));
}
