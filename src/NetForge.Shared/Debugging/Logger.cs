using System;
using System.Runtime.CompilerServices;

namespace NetForge.Shared.Debugging;

public class Logger
{
	public static event Action<string> MessageLoggedEvent = delegate { };

	public static void Log(
		string message,
		[CallerMemberName] string callerMemberName = "",
		[CallerFilePath] string callerFilePath = "",
		[CallerLineNumber] int callerLineNumber = 0
	)
	{
		// string fileName = System.IO.Path.GetFileName(callerFilePath);
		// string formattedMessage = $"[{fileName}:{callerLineNumber}:{callerMemberName}] - {message}";
		string formattedMessage = message;

		Console.WriteLine(formattedMessage);
		MessageLoggedEvent(formattedMessage);
	}
}