/**
Implements logging facilities.

Message logging is a common approach to expose runtime information of a
program. Logging should be easy, but also flexible and powerful, therefore $(D
D) provides a standard interface for logging.

The easiest way to create a log message is to write $(D import std.logger;
log("I am here");) this will print a message to the stdio device.  The message
will contain the filename, the linenumber, the name of the surrounding
function and the message. 

Copyright: Copyright Robert burner Schadek 2013.
License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
Authors:   $(WEB http://www.svs.informatik.uni-oldenburg.de/60865.html, Robert burner Schadek)

Example:
-------------
log("Logging to the defaultLogger with its default LogLevel");
logInfo("Logging to the defaultLogger with its info LogLevel");
logWarning(5 < 6, "Logging to the defaultLogger with its LogLevel.warning if 5 is less than 6");
logError("Logging to the defaultLogger with its error LogLevel");
logCritical("Logging to the defaultLogger with its error LogLevel");
logFatal("Logging to the defaultLogger with its fatal LogLevel");

auto fileLogger = new FileLogger("NameOfTheLogFile");
fileLogger.log("Logging to the fileLogger with its default LogLevel");
fileLogger.logInfo("Logging to the fileLogger with its default LogLevel");
fileLogger.logWarning(5 < 6, "Logging to the fileLogger with its LogLevel.warning if 5 is less than 6");
fileLogger.logCritical("Logging to the fileLogger with its info LogLevel");
fileLogger.log(5 < 6, "Logging to the fileLogger with its default LogLevel if 5 is less than 6");
fileLogger.logFatal("Logging to the fileLogger with its warning LogLevel");
-------------

For conditional logging pass a boolean to the log or logf functions. Only if
the condition pass is true the message will be logged.

Messages are logged if the $(D LogLevel) of the log message is greater equal
than the $(D LogLevel) of the used $(D Logger) and the global $(D LogLevel).
To assign the $(D LogLevel) of a $(D Logger) use the $(D logLevel) property of
the logger. The global $(D LogLevel) is managed by the static $(D LogManager).
It can be changed by assigning the $(D globalLogLevel) property of the $(D
LogManager).

To customize the logger behaviour, create a new $(D class) that inherits from
the abstract $(D Logger) $(D class) and implements the $(D writeLogMsg) method.
Example:
-------------
class MyCustomLogger : Logger {
    override void writeLogMsg(LoggerPayload payload)
    {
        // log message in my custom way
    }
}

auto logger = new MyCustomLogger();
logger.log("Awesome log message");
-------------

In order to disable logging at compile time, pass $(D DisableLogger) as a
version argument to the $(D D) compiler.
*/

module std.logger;

import std.stdio;
import std.conv;
import std.datetime;
import std.string;
import std.exception;
import std.concurrency;

private pure string logLevelToParameterString(const LogLevel lv) 
{
	final switch(lv) 
	{
		case LogLevel.unspecific:
			return "this.logLevel_";
		case LogLevel.info:
			return "LogLevel.info";
		case LogLevel.warning:
			return "LogLevel.warning";
		case LogLevel.error:
			return "LogLevel.error";
		case LogLevel.critical:
			return "LogLevel.critical";
		case LogLevel.fatal:
			return "LogLevel.fatal";
	}
}

private pure string logLevelToFuncNameString(const LogLevel lv) 
{
	final switch(lv) 
	{
		case LogLevel.unspecific:
			return "";
		case LogLevel.info:
			return "Info";
		case LogLevel.warning:
			return "Warning";
		case LogLevel.error:
			return "Error";
		case LogLevel.critical:
			return "Critical";
		case LogLevel.fatal:
			return "Fatal";
	}
}

private string genDocComment(const bool asMemberFunction, 
		const bool asConditional, const bool asPrintf, 
		const bool specificLogLevel, const LogLevel lv) 
{
	string ret = "/**\n * This ";
	ret ~= asMemberFunction ? "member " : "";
	ret ~= "function ";
	ret ~= "logs a string message " ~ 
		(asPrintf ? "in a printf like fashion " : "") ~
		(asConditional ? "depending on a condition " : "") ~
		(specificLogLevel ? 
		 	("with log level " ~ logLevelToParameterString(lv)) : ""
		) ~ ".\n *\n";

	ret ~= " * This ";
	ret ~= asMemberFunction ? "member " : "";
	ret ~= "function takes ";

	if(specificLogLevel) 
	{
		ret ~= "a $(D LogLevel) as first argument.";
		if(asConditional) 
		{
			ret ~= " In addition to the $(D bool) value passed the passed "
				~ "$(D LogLevel) determines if the message is logged. ";
			ret ~= " The second argument is a $(D bool) value. If the value is"
				~ " $(D true) the message will be logged solely depending on"
				~ " its $(D LogLevel). If the value is $(D false) the message"
				~ " will ot be logged.";
		}
	} 
	else if(asConditional) 
	{
		ret ~= "a $(D bool) as first argument." 
			~ " If the value is $(D true) the message will be logged solely"
			~ " depending on its $(D LogLevel). If the value is $(D false)"
			~ " the message will ot be logged.";
	}
	else
	{
		ret ~= "the log message as first argument.";
	}

	if(!specificLogLevel) 
	{
		ret ~= " The $(D LogLevel) of the message is $(D " ~
			logLevelToParameterString(lv) ~ ").";
	}

	ret ~= " In order for the message to be processed the "
		~ "$(D LogLevel) must be greater equal to the $(D LogLevel) of "
		~ "the used logger and the global $(D LogLevel).";

	ret ~= asPrintf ? "The log message can contain printf style format"
		~ " sequences that will be combined with the passed variadic"
		~ " arguements.": "";

	ret ~= "\n *\n * Params:\n";

	ret ~= asConditional ? " * cond = The $(D bool) value indicating if the"
		~ " message should be logged.\n" : "";

	ret ~= specificLogLevel ? " * logLevel = The $(D LogLevel) of the"
		~ " message.\n" : "";

	ret ~= " * msg = The message that should be logged.\n";

	ret ~= asPrintf ? " * a = The format arguments that will be used"
		~ " to printf style formatting.\n" : "";

	ret ~= asMemberFunction ? "\n *\n * Returns: The logger used for by the logging"
		~ " member function" : "";

	ret ~= " * \n * \n * Examples:\n * --------------------\n";
	ret ~= asMemberFunction ? " * someLogger.log" : " * log";
	ret ~= !specificLogLevel ? logLevelToFuncNameString(lv) : "";
	ret ~= asPrintf ? "F(" : "(";
	ret ~= specificLogLevel ? "someLogLevel, " : "";
	ret ~= asConditional ? "someBoolValue, " : "";
	ret ~= asPrintf ? "Hello %s, \"World\"" : "Hello World";
	
	ret ~= ");\n * --------------------\n";
		
	return ret ~ " */\n";
}

//pragma(msg, genDocComment(false, true, false, false, LogLevel.critical));
//pragma(msg, genDocComment(true, true, true, true, LogLevel.critical));

private string buildLogFunction(const bool asMemberFunction, 
		const bool asConditional, const bool asPrintf, 
		const bool specificLogLevel, const LogLevel lv) 
{
	string ret = genDocComment(asMemberFunction, asConditional, asPrintf,
		specificLogLevel, lv);
	ret ~= asMemberFunction ? "\tvoid " : "public ref Logger ";
	ret ~= "log" ~ logLevelToFuncNameString(lv);
  	ret ~= asPrintf ? "F(" : "(";
	if(asPrintf) {
		ret ~= "int line = __LINE__, string file = __FILE__, string funcName"
		   " = __FUNCTION__, string prettyFuncName = __PRETTY_FUNCTION__, "
		   "A...)(";

		ret ~= specificLogLevel ? "const LogLevel logLevel, " : "";

		if(asConditional) {
			ret ~= "bool cond, ";
		}
		ret ~= "string msg, A a";
	} else {
		ret ~= specificLogLevel ? "const LogLevel logLevel, " : "";

		if(asConditional) {
			ret ~= "bool cond, ";
		}
		ret ~= "string msg = \"\", int line = __LINE__, string file = "
			"__FILE__, string funcName = __FUNCTION__, string prettyFuncName"
		    " = __PRETTY_FUNCTION__";
	}

	ret ~= ") {\n";
	
	if(asMemberFunction) {
		ret ~= "\t\tthis.logMessage(file, line, funcName, prettyFuncName, ";
		ret ~= specificLogLevel ? "logLevel, " : 
			logLevelToParameterString(lv) ~ ", ";

	   	ret ~= asConditional ? "cond, " : "true, ";
		ret ~= asPrintf ? "format(msg, a));" : "msg);";
		ret ~= "\n\t}\n";
	} else {
		ret ~= "\tLogManager.defaultLogger.log(";
		if(specificLogLevel) {
			ret ~= "logLevel, ";
		} else {
			ret ~= lv == LogLevel.unspecific ? "LogManager.globalLogLevel, " : 
				logLevelToParameterString(lv) ~ ", ";
		}
		ret ~= asConditional ? "cond, " : "true, ";
	   	ret ~= asPrintf ? "format(msg, a), " : "msg, ";
	   	ret ~= "line, file, funcName, prettyFuncName);\n";
		ret ~= "\treturn LogManager.defaultLogger;";
		ret ~= "\n}\n";
	}

	return ret;
}

//pragma(msg, buildLogFunction(false, true, false, true, LogLevel.unspecific));
//pragma(msg, buildLogFunction(false, false, true, false, LogLevel.unspecific));
//pragma(msg, buildLogFunction(false, true, false, true, LogLevel.unspecific));
//pragma(msg, buildLogFunction(false, false, false, true, LogLevel.unspecific));
//pragma(msg, buildLogFunction(false, false, false, false, LogLevel.unspecific));

/**
There are five usable logging level. These level are $(I info), $(I warning),
$(I error), $(I critical) and $(I fatal). Ever log message and every $(D
Logger) has a LogLevel associated with it, as does every log message.
*/
enum LogLevel
{
    unspecific,     /** If no $(D LogLevel) is passed to the log function this
                    level indicates that the current level of the $(D Logger)
                    is to be used for logging the message.  */
    info,         /** This level is used to display information about the
                      program. */
    warning,     /** warnings about the program should be displayed with this
                  level. */
    error,         /** Information about errors should be logged with this level.*/
    critical,     /** Messages that inform about critical errors should be
                  logged with this level. */
    fatal         /** Log messages that describe fatel errors should use this
                  level. */
}

/** This class is the base of every logger. In order to create a new kind of
logger a derivating class needs to implementation the method $(D writeLogMsg).
*/
abstract class Logger
{
    /** LoggerPayload is a aggregation combining all information associated
    with a log message. This aggregation will be passed to the method
    writeLogMsg.
    */
    protected struct LoggerPayload 
    {
        /// the filename the log function was called from
        string file;
        /// the line number the log function was called from
        int line;
        /// the name of the function the log function was called from
        string funcName;
        /// the pretty formatted name of the function the log function was called from
        string prettyFuncName;
        /// the $(D LogLevel) associated with the log message
        LogLevel logLevel;
        /// the time the message was logged.
        SysTime timestamp;
        /// thread id
        Tid threadId;
        /// the message
        string msg;

        // Helper
        static LoggerPayload opCall(string file, int line, string funcName,
                string prettyFuncName, LogLevel logLevel, SysTime timestamp,
                Tid threadId, string msg) 
        {
            LoggerPayload ret;
            ret.file = file;
            ret.line = line;
            ret.funcName = funcName;
            ret.prettyFuncName = prettyFuncName;
            ret.logLevel = logLevel;
            ret.timestamp = timestamp;
            ret.threadId = threadId;
            ret.msg = msg;
            return ret;
        }
    }
    /** This constructor of the abstract logger has one arguments. The argument
    defines the $(D LogLevel) of the $(D Logger). By default the $(D LogLevel) is
    set to $(D info). If a custom constructor is needed the selected $(D LogLevel)
    needs to be passed to the super constructor.
    */
    public this(LogLevel lv = LogLevel.info)
    {
        this.logLevel = lv;
    }

    /** This constructor takes a name of type $(D string) and a $(D LogLevel)
    that is set to $(D LogLevel.info) by default.
    */
    public this(string newName, LogLevel lv = LogLevel.info)
    {
        this(lv);
        this.name = newName;
    }

    /** A custom logger needs to implement this method.
    Params:
        payload = All information associated with call to log function.
    */
    public void writeLogMsg(LoggerPayload payload);

    /** This method is the entry point into each logger. It compares the given
    $(D LogLevel) with the $(D LogLevel) of the $(D Logger) and the global
    $(LogLevel). If the passed $(D LogLevel) is greater or equal to both the
    message and all other parameter are passed to the abstract method
    $(D writeLogMsg).
    */
    public void logMessage(string file, int line, string funcName,
            string prettyFuncName, LogLevel logLevel, bool cond, string msg)
    {
        version(DisableLogger)
        {
        }
        else
        {
			const bool ll = logLevel >= this.logLevel_;
			const bool gll = logLevel >= LogManager.globalLogLevel;
            if (cond && ll && gll)
            {
                writeLogMsg(LoggerPayload(file, line, funcName, prettyFuncName,
                    logLevel, Clock.currTime, thisTid, msg));
            }
        }
    }

    /** Get the $(D LogLevel) of the logger. */
    public @property final LogLevel logLevel() const pure nothrow
    {
        return this.logLevel_;
    }

    /** Set the $(D LogLevel) of the logger. The $(D LogLevel) can not be set
    to $(D LogLevel.unspecific).*/
    public @property final void logLevel(const LogLevel lv) pure nothrow
    {
        assert(lv != LogLevel.unspecific);
        this.logLevel_ = lv;
    }

    /** Get the $(D name) of the logger. */
    public @property final string name() const pure nothrow
    {
        return this.name_;
    }

    /** Set the $(D LogLevel) of the logger. The $(D LogLevel) can not be set
    to $(D LogLevel.unspecific).*/
    public @property final void name(string newName) pure nothrow
    {
        this.name_ = newName;
    }

	/**
	 * This member function logs a string message .
	 *
	 * This member function takes the log message as first argument. The $(D
	 * LogLevel) of the message is $(D this.logLevel_). In order for the
	 * message to be processed the $(D LogLevel) must be greater equal to the
	 * $(D LogLevel) of the used logger and the global $(D LogLevel).
	 *
	 * Params:
	 * msg = The message that should be logged.
	 *
	 *
	 * Returns: The logger used for by the logging member function * 
	 * 
	 * Examples:
	 * --------------------
	 * someLogger.log(Hello World);
	 * --------------------
	 */
	void log(string msg = "", int line = __LINE__, string file = __FILE__, 
				string funcName = __FUNCTION__, 
				string prettyFuncName = __PRETTY_FUNCTION__) {
			this.logMessage(file, line, funcName, prettyFuncName, 
				this.logLevel_, true, msg);
		}
	
	/**
	 * This member function logs a string message .
	 *
	 * This member function takes the log message as first argument. The $(D
	 * LogLevel) of the message is $(D LogLevel.info). In order for the
	 * message to be processed the $(D LogLevel) must be greater equal to the
	 * $(D LogLevel) of the used logger and the global $(D LogLevel).
	 *
	 * Params:
	 * msg = The message that should be logged.
 	 *	
	 *
	 * Returns: The logger used for by the logging member function * 
	 * 
	 * Examples:
	 * --------------------
	 * someLogger.logInfo(Hello World);
	 * --------------------
	 */
	void logInfo(string msg = "", int line = __LINE__, string file = __FILE__, 
				string funcName = __FUNCTION__, 
				string prettyFuncName = __PRETTY_FUNCTION__) {
		this.logMessage(file, line, funcName, prettyFuncName, LogLevel.info, 
			true, msg);
	}
	
	/**
	 * This member function logs a string message .
	 *
	 * This member function takes the log message as first argument. The $(D
	 * LogLevel) of the message is $(D LogLevel.warning). In order for the
	 * message to be processed the $(D LogLevel) must be greater equal to the
	 * $(D LogLevel) of the used logger and the global $(D LogLevel).
	 *
	 * Params:
	 * msg = The message that should be logged.
	 *
	 *
	 * Returns: The logger used for by the logging member function * 
	 * 
	 * Examples:
	 * --------------------
	 * someLogger.logWarning(Hello World);
	 * --------------------
	 */
	void logWarning(string msg = "", int line = __LINE__, 
				string file = __FILE__, string funcName = __FUNCTION__, 
				string prettyFuncName = __PRETTY_FUNCTION__) {
		this.logMessage(file, line, funcName, prettyFuncName, 
			LogLevel.warning, true, msg);
	}
	
	/**
	 * This member function logs a string message .
	 *
	 * This member function takes the log message as first argument. The $(D
	 * LogLevel) of the message is $(D LogLevel.error). In order for the
	 * message to be processed the $(D LogLevel) must be greater equal to the
	 * $(D LogLevel) of the used logger and the global $(D LogLevel).
	 *
	 * Params:
	 * msg = The message that should be logged.
	 *
	 *
	 * Returns: The logger used for by the logging member function * 
	 * 
	 * Examples:
	 * --------------------
	 * someLogger.logError(Hello World);
	 * --------------------
	 */
	void logError(string msg = "", int line = __LINE__, 
			string file = __FILE__, string funcName = __FUNCTION__, 
			string prettyFuncName = __PRETTY_FUNCTION__) {
		this.logMessage(file, line, funcName, prettyFuncName, LogLevel.error, 
			true, msg);
		}
	
	/**
	 * This member function logs a string message .
	 *
	 * This member function takes the log message as first argument. The $(D
	 * LogLevel) of the message is $(D LogLevel.critical). In order for the
	 * message to be processed the $(D LogLevel) must be greater equal to the
	 * $(D LogLevel) of the used logger and the global $(D LogLevel).
	 *
	 * Params:
	 * msg = The message that should be logged.
	 *
	 * Returns: The logger used for by the logging member function * 
	 * 
	 * Examples:
	 * --------------------
	 * someLogger.logCritical(Hello World);
	 * --------------------
	 */
	void logCritical(string msg = "", int line = __LINE__, 
			string file = __FILE__, string funcName = __FUNCTION__, 
			string prettyFuncName = __PRETTY_FUNCTION__) {
		this.logMessage(file, line, funcName, prettyFuncName, 
			LogLevel.critical, true, msg);
	}
	
	/**
	 * This member function logs a string message .
	 *
	 * This member function takes the log message as first argument. The $(D
	 * LogLevel) of the message is $(D LogLevel.fatal). In order for the
	 * message to be processed the $(D LogLevel) must be greater equal to the
	 * $(D LogLevel) of the used logger and the global $(D LogLevel).
	 *
	 * Params:
	 * msg = The message that should be logged.
	 *
	 * Returns: The logger used for by the logging member function * 
	 * 
	 * Examples:
	 * --------------------
	 * someLogger.logFatal(Hello World);
	 * --------------------
	 */
	void logFatal(string msg = "", int line = __LINE__, 
			string file = __FILE__, string funcName = __FUNCTION__, 
			string prettyFuncName = __PRETTY_FUNCTION__) {
		this.logMessage(file, line, funcName, prettyFuncName, LogLevel.fatal, 
			true, msg);
	}

	/**
	 * This member function logs a string message in a printf like fashion .
	 *
	 * This member function takes the log message as first argument. The $(D
	 * LogLevel) of the message is $(D this.logLevel_). In order for the
	 * message to be processed the $(D LogLevel) must be greater equal to the
	 * $(D LogLevel) of the used logger and the global $(D LogLevel).The log
	 * message can contain printf style format sequences that will be combined
	 * with the passed variadic arguements.
	 *
	 * Params:
	 * msg = The message that should be logged.
	 * a = The format arguments that will be used to printf style formatting.
	 *
	 * Returns: The logger used for by the logging member function * 
	 * 
	 * Examples:
	 * --------------------
	 * someLogger.logF(Hello %s, "World");
	 * --------------------
	 */
	void logF(int line = __LINE__, string file = __FILE__, 
			string funcName = __FUNCTION__, 
			string prettyFuncName = __PRETTY_FUNCTION__, A...)
			(string msg, A a) {
		this.logMessage(file, line, funcName, prettyFuncName, this.logLevel_, 
			true, format(msg, a));
	}
	
	/**
	 * This member function logs a string message in a printf like fashion .
	 *
	 * This member function takes the log message as first argument. The $(D
	 * LogLevel) of the message is $(D LogLevel.info). In order for the
	 * message to be processed the $(D LogLevel) must be greater equal to the
	 * $(D LogLevel) of the used logger and the global $(D LogLevel).The log
	 * message can contain printf style format sequences that will be combined
	 * with the passed variadic arguements.
	 *
	 * Params:
	 * msg = The message that should be logged.
	 * a = The format arguments that will be used to printf style formatting.
	 *
	 * Returns: The logger used for by the logging member function * 
	 * 
	 * Examples:
	 * --------------------
	 * someLogger.logInfoF(Hello %s, "World");
	 * --------------------
	 */
	void logInfoF(int line = __LINE__, string file = __FILE__, 
			string funcName = __FUNCTION__, 
			string prettyFuncName = __PRETTY_FUNCTION__, A...)
			(string msg, A a) {
		this.logMessage(file, line, funcName, prettyFuncName, LogLevel.info, 
			true, format(msg, a));
	}
	
	/**
	 * This member function logs a string message in a printf like fashion .
	 *
	 * This member function takes the log message as first argument. The $(D
	 * LogLevel) of the message is $(D LogLevel.warning). In order for the
	 * message to be processed the $(D LogLevel) must be greater equal to the
	 * $(D LogLevel) of the used logger and the global $(D LogLevel).The log
	 * message can contain printf style format sequences that will be combined
	 * with the passed variadic arguements.
	 *
	 * Params:
	 * msg = The message that should be logged.
	 * a = The format arguments that will be used to printf style formatting.
	 *
	 * Returns: The logger used for by the logging member function * 
	 * 
	 * Examples:
	 * --------------------
	 * someLogger.logWarningF(Hello %s, "World");
	 * --------------------
	 */
	void logWarningF(int line = __LINE__, string file = __FILE__, 
			string funcName = __FUNCTION__, 
			string prettyFuncName = __PRETTY_FUNCTION__, A...)
			(string msg, A a) {
		this.logMessage(file, line, funcName, prettyFuncName, 
			LogLevel.warning, true, format(msg, a));
	}
	
	/**
	 * This member function logs a string message in a printf like fashion .
	 *
	 * This member function takes the log message as first argument. The $(D
	 * LogLevel) of the message is $(D LogLevel.error). In order for the
	 * message to be processed the $(D LogLevel) must be greater equal to the
	 * $(D LogLevel) of the used logger and the global $(D LogLevel).The log
	 * message can contain printf style format sequences that will be combined
	 * with the passed variadic arguements.
	 *
	 * Params:
	 * msg = The message that should be logged.
	 * a = The format arguments that will be used to printf style formatting.
	 *
	 * Returns: The logger used for by the logging member function * 
	 * 
	 * Examples:
	 * --------------------
	 * someLogger.logErrorF(Hello %s, "World");
	 * --------------------
	 */
	void logErrorF(int line = __LINE__, string file = __FILE__, 
			string funcName = __FUNCTION__, 
			string prettyFuncName = __PRETTY_FUNCTION__, A...)
			(string msg, A a) {
		this.logMessage(file, line, funcName, prettyFuncName, LogLevel.error, 
			true, format(msg, a));
	}
	
	/**
	 * This member function logs a string message in a printf like fashion .
	 *
	 * This member function takes the log message as first argument. The $(D
	 * LogLevel) of the message is $(D LogLevel.critical). In order for the
	 * message to be processed the $(D LogLevel) must be greater equal to the
	 * $(D LogLevel) of the used logger and the global $(D LogLevel).The log
	 * message can contain printf style format sequences that will be combined
	 * with the passed variadic arguements.
	 *
	 * Params:
	 * msg = The message that should be logged.
	 * a = The format arguments that will be used to printf style formatting.
	 *
	 * Returns: The logger used for by the logging member function * 
	 * 
	 * Examples:
	 * --------------------
	 * someLogger.logCriticalF(Hello %s, "World");
	 * --------------------
	 */
	void logCriticalF(int line = __LINE__, string file = __FILE__, 
			string funcName = __FUNCTION__, 
			string prettyFuncName = __PRETTY_FUNCTION__, A...)
			(string msg, A a) {
		this.logMessage(file, line, funcName, prettyFuncName, 
			LogLevel.critical, true, format(msg, a));
	}
	
	/**
	 * This member function logs a string message in a printf like fashion .
	 *
	 * This member function takes the log message as first argument. The $(D
	 * LogLevel) of the message is $(D LogLevel.fatal). In order for the
	 * message to be processed the $(D LogLevel) must be greater equal to the
	 * $(D LogLevel) of the used logger and the global $(D LogLevel).The log
	 * message can contain printf style format sequences that will be combined
	 * with the passed variadic arguements.
	 *
	 * Params:
	 * msg = The message that should be logged.
	 * a = The format arguments that will be used to printf style formatting.
	 *
	 * Returns: The logger used for by the logging member function * 
	 * 
	 * Examples:
	 * --------------------
	 * someLogger.logFatalF(Hello %s, "World");
	 * --------------------
	 */
	void logFatalF(int line = __LINE__, string file = __FILE__, 
			string funcName = __FUNCTION__, 
			string prettyFuncName = __PRETTY_FUNCTION__, A...)
			(string msg, A a) {
		this.logMessage(file, line, funcName, prettyFuncName, LogLevel.fatal, 
			true, format(msg, a));
	}
	
	/**
	 * This member function logs a string message depending on a condition .
	 *
	 * This member function takes a $(D bool) as first argument. If the value
	 * is $(D true) the message will be logged solely depending on its $(D
	 * LogLevel). If the value is $(D false) the message will ot be logged.
	 * The $(D LogLevel) of the message is $(D this.logLevel_). In order for
	 * the message to be processed the $(D LogLevel) must be greater equal to
	 * the $(D LogLevel) of the used logger and the global $(D LogLevel).
	 *
	 * Params:
	 * cond = The $(D bool) value indicating if the message should be logged.
	 * msg = The message that should be logged.
	 *
	 * Returns: The logger used for by the logging member function * 
	 * 
	 * Examples:
	 * --------------------
	 * someLogger.log(someBoolValue, Hello World);
	 * --------------------
	 */
	void log(bool cond, string msg = "", int line = __LINE__, 
			string file = __FILE__, string funcName = __FUNCTION__, 
			string prettyFuncName = __PRETTY_FUNCTION__) {
		this.logMessage(file, line, funcName, prettyFuncName, this.logLevel_, 
			cond, msg);
	}
	
	/**
	 * This member function logs a string message depending on a condition .
	 *
	 * This member function takes a $(D bool) as first argument. If the value
	 * is $(D true) the message will be logged solely depending on its $(D
	 * LogLevel). If the value is $(D false) the message will ot be logged.
	 * The $(D LogLevel) of the message is $(D LogLevel.info). In order for
	 * the message to be processed the $(D LogLevel) must be greater equal to
	 * the $(D LogLevel) of the used logger and the global $(D LogLevel).
	 *
	 * Params:
	 * cond = The $(D bool) value indicating if the message should be logged.
	 * msg = The message that should be logged.
	 *
	 * Returns: The logger used for by the logging member function * 
	 * 
	 * Examples:
	 * --------------------
	 * someLogger.logInfo(someBoolValue, Hello World);
	 * --------------------
	 */
	void logInfo(bool cond, string msg = "", int line = __LINE__, string file = __FILE__, 
			string funcName = __FUNCTION__, 
			string prettyFuncName = __PRETTY_FUNCTION__) {
		this.logMessage(file, line, funcName, prettyFuncName, LogLevel.info, cond, msg);
	}
	
	/**
	 * This member function logs a string message depending on a condition .
	 *
	 * This member function takes a $(D bool) as first argument. If the value
	 * is $(D true) the message will be logged solely depending on its $(D
	 * LogLevel). If the value is $(D false) the message will ot be logged.
	 * The $(D LogLevel) of the message is $(D LogLevel.warning). In order for
	 * the message to be processed the $(D LogLevel) must be greater equal to
	 * the $(D LogLevel) of the used logger and the global $(D LogLevel).
	 *
	 * Params:
	 * cond = The $(D bool) value indicating if the message should be logged.
	 * msg = The message that should be logged.
	 *
	 * Returns: The logger used for by the logging member function * 
	 * 
	 * Examples:
	 * --------------------
	 * someLogger.logWarning(someBoolValue, Hello World);
	 * --------------------
	 */
	void logWarning(bool cond, string msg = "", int line = __LINE__, 
			string file = __FILE__, string funcName = __FUNCTION__, 
			string prettyFuncName = __PRETTY_FUNCTION__) {
		this.logMessage(file, line, funcName, prettyFuncName, LogLevel.warning, cond, msg);
	}
	
	/**
	 * This member function logs a string message depending on a condition .
	 *
	 * This member function takes a $(D bool) as first argument. If the value
	 * is $(D true) the message will be logged solely depending on its $(D
	 * LogLevel). If the value is $(D false) the message will ot be logged.
	 * The $(D LogLevel) of the message is $(D LogLevel.error). In order for
	 * the message to be processed the $(D LogLevel) must be greater equal to
	 * the $(D LogLevel) of the used logger and the global $(D LogLevel).
	 *
	 * Params:
	 * cond = The $(D bool) value indicating if the message should be logged.
	 * msg = The message that should be logged.
	 *
	 * Returns: The logger used for by the logging member function * 
	 * 
	 * Examples:
	 * --------------------
	 * someLogger.logError(someBoolValue, Hello World);
	 * --------------------
	 */
	void logError(bool cond, string msg = "", int line = __LINE__, string file = __FILE__, string funcName = __FUNCTION__, string prettyFuncName = __PRETTY_FUNCTION__) {
			this.logMessage(file, line, funcName, prettyFuncName, LogLevel.error, cond, msg);
	}
	
	/**
	 * This member function logs a string message depending on a condition .
	 *
	 * This member function takes a $(D bool) as first argument. If the value
	 * is $(D true) the message will be logged solely depending on its $(D
	 * LogLevel). If the value is $(D false) the message will ot be logged.
	 * The $(D LogLevel) of the message is $(D LogLevel.critical). In order
	 * for the message to be processed the $(D LogLevel) must be greater equal
	 * to the $(D LogLevel) of the used logger and the global $(D LogLevel).
	 *
	 * Params:
	 * cond = The $(D bool) value indicating if the message should be logged.
	 * msg = The message that should be logged.
	
	 *
	 * Returns: The logger used for by the logging member function * 
	 * 
	 * Examples:
	 * --------------------
	 * someLogger.logCritical(someBoolValue, Hello World);
	 * --------------------
	 */
	void logCritical(bool cond, string msg = "", int line = __LINE__, string file = __FILE__, string funcName = __FUNCTION__, string prettyFuncName = __PRETTY_FUNCTION__) {
			this.logMessage(file, line, funcName, prettyFuncName, LogLevel.critical, cond, msg);
	}
	
	/**
	 * This member function logs a string message depending on a condition .
	 *
	 * This member function takes a $(D bool) as first argument. If the value
	 * is $(D true) the message will be logged solely depending on its $(D
	 * LogLevel). If the value is $(D false) the message will ot be logged.
	 * The $(D LogLevel) of the message is $(D LogLevel.fatal). In order for
	 * the message to be processed the $(D LogLevel) must be greater equal to
	 * the $(D LogLevel) of the used logger and the global $(D LogLevel).
	 *
	 * Params:
	 * cond = The $(D bool) value indicating if the message should be logged.
	 * msg = The message that should be logged.
	
	 *
	 * Returns: The logger used for by the logging member function * 
	 * 
	 * Examples:
	 * --------------------
	 * someLogger.logFatal(someBoolValue, Hello World);
	 * --------------------
	 */
	void logFatal(bool cond, string msg = "", int line = __LINE__, string file = __FILE__, string funcName = __FUNCTION__, string prettyFuncName = __PRETTY_FUNCTION__) {
			this.logMessage(file, line, funcName, prettyFuncName, LogLevel.fatal, cond, msg);
	}
	
	/**
	 * This member function logs a string message in a printf like fashion depending on a condition .
	 *
	 * This member function takes a $(D bool) as first argument. If the value
	 * is $(D true) the message will be logged solely depending on its $(D
	 * LogLevel). If the value is $(D false) the message will ot be logged.
	 * The $(D LogLevel) of the message is $(D this.logLevel_). In order for
	 * the message to be processed the $(D LogLevel) must be greater equal to
	 * the $(D LogLevel) of the used logger and the global $(D LogLevel).The
	 * log message can contain printf style format sequences that will be
	 * combined with the passed variadic arguements.
	 *
	 * Params:
	 * cond = The $(D bool) value indicating if the message should be logged.
	 * msg = The message that should be logged.
	 * a = The format arguments that will be used to printf style formatting.
	
	 *
	 * Returns: The logger used for by the logging member function * 
	 * 
	 * Examples:
	 * --------------------
	 * someLogger.logF(someBoolValue, Hello %s, "World");
	 * --------------------
	 */
	void logF(int line = __LINE__, string file = __FILE__, string funcName = __FUNCTION__, string prettyFuncName = __PRETTY_FUNCTION__, A...)(bool cond, string msg, A a) {
			this.logMessage(file, line, funcName, prettyFuncName, this.logLevel_, cond, format(msg, a));
	}
	
	/**
	 * This member function logs a string message in a printf like fashion depending on a condition .
	 *
	 * This member function takes a $(D bool) as first argument. If the value is $(D true) the message will be logged solely depending on its $(D LogLevel). If the value is $(D false) the message will ot be logged. The $(D LogLevel) of the message is $(D LogLevel.info). In order for the message to be processed the $(D LogLevel) must be greater equal to the $(D LogLevel) of the used logger and the global $(D LogLevel).The log message can contain printf style format sequences that will be combined with the passed variadic arguements.
	 *
	 * Params:
	 * cond = The $(D bool) value indicating if the message should be logged.
	 * msg = The message that should be logged.
	 * a = The format arguments that will be used to printf style formatting.
	
	 *
	 * Returns: The logger used for by the logging member function * 
	 * 
	 * Examples:
	 * --------------------
	 * someLogger.logInfoF(someBoolValue, Hello %s, "World");
	 * --------------------
	 */
	void logInfoF(int line = __LINE__, string file = __FILE__, string funcName = __FUNCTION__, string prettyFuncName = __PRETTY_FUNCTION__, A...)(bool cond, string msg, A a) {
			this.logMessage(file, line, funcName, prettyFuncName, LogLevel.info, cond, format(msg, a));
		}
	
	/**
	 * This member function logs a string message in a printf like fashion depending on a condition .
	 *
	 * This member function takes a $(D bool) as first argument. If the value
	 * is $(D true) the message will be logged solely depending on its $(D
	 * LogLevel). If the value is $(D false) the message will ot be logged.
	 * The $(D LogLevel) of the message is $(D LogLevel.warning). In order for
	 * the message to be processed the $(D LogLevel) must be greater equal to
	 * the $(D LogLevel) of the used logger and the global $(D LogLevel).The
	 * log message can contain printf style format sequences that will be
	 * combined with the passed variadic arguements.
	 *
	 * Params:
	 * cond = The $(D bool) value indicating if the message should be logged.
	 * msg = The message that should be logged.
	 * a = The format arguments that will be used to printf style formatting.
	
	 *
	 * Returns: The logger used for by the logging member function * 
	 * 
	 * Examples:
	 * --------------------
	 * someLogger.logWarningF(someBoolValue, Hello %s, "World");
	 * --------------------
	 */
	void logWarningF(int line = __LINE__, string file = __FILE__, string funcName = __FUNCTION__, string prettyFuncName = __PRETTY_FUNCTION__, A...)(bool cond, string msg, A a) {
			this.logMessage(file, line, funcName, prettyFuncName, LogLevel.warning, cond, format(msg, a));
	}
	
	/**
	 * This member function logs a string message in a printf like fashion depending on a condition .
	 *
	 * This member function takes a $(D bool) as first argument. If the value
	 * is $(D true) the message will be logged solely depending on its $(D
	 * LogLevel). If the value is $(D false) the message will ot be logged.
	 * The $(D LogLevel) of the message is $(D LogLevel.error). In order for
	 * the message to be processed the $(D LogLevel) must be greater equal to
	 * the $(D LogLevel) of the used logger and the global $(D LogLevel).The
	 * log message can contain printf style format sequences that will be
	 * combined with the passed variadic arguements.
	 *
	 * Params:
	 * cond = The $(D bool) value indicating if the message should be logged.
	 * msg = The message that should be logged.
	 * a = The format arguments that will be used to printf style formatting.
	
	 *
	 * Returns: The logger used for by the logging member function * 
	 * 
	 * Examples:
	 * --------------------
	 * someLogger.logErrorF(someBoolValue, Hello %s, "World");
	 * --------------------
	 */
	void logErrorF(int line = __LINE__, string file = __FILE__, string funcName = __FUNCTION__, string prettyFuncName = __PRETTY_FUNCTION__, A...)(bool cond, string msg, A a) {
			this.logMessage(file, line, funcName, prettyFuncName, LogLevel.error, cond, format(msg, a));
	}
	
	/**
	 * This member function logs a string message in a printf like fashion depending on a condition .
	 *
	 * This member function takes a $(D bool) as first argument. If the value
	 * is $(D true) the message will be logged solely depending on its $(D
	 * LogLevel). If the value is $(D false) the message will ot be logged.
	 * The $(D LogLevel) of the message is $(D LogLevel.critical). In order
	 * for the message to be processed the $(D LogLevel) must be greater equal
	 * to the $(D LogLevel) of the used logger and the global $(D
	 * LogLevel).The log message can contain printf style format sequences
	 * that will be combined with the passed variadic arguements.
	 *
	 * Params:
	 * cond = The $(D bool) value indicating if the message should be logged.
	 * msg = The message that should be logged.
	 * a = The format arguments that will be used to printf style formatting.
	
	 *
	 * Returns: The logger used for by the logging member function * 
	 * 
	 * Examples:
	 * --------------------
	 * someLogger.logCriticalF(someBoolValue, Hello %s, "World");
	 * --------------------
	 */
	void logCriticalF(int line = __LINE__, string file = __FILE__, string funcName = __FUNCTION__, string prettyFuncName = __PRETTY_FUNCTION__, A...)(bool cond, string msg, A a) {
			this.logMessage(file, line, funcName, prettyFuncName, LogLevel.critical, cond, format(msg, a));
	}
	
	/**
	 * This member function logs a string message in a printf like fashion depending on a condition .
	 *
	 * This member function takes a $(D bool) as first argument. If the value
	 * is $(D true) the message will be logged solely depending on its $(D
	 * LogLevel). If the value is $(D false) the message will ot be logged.
	 * The $(D LogLevel) of the message is $(D LogLevel.fatal). In order for
	 * the message to be processed the $(D LogLevel) must be greater equal to
	 * the $(D LogLevel) of the used logger and the global $(D LogLevel).The
	 * log message can contain printf style format sequences that will be
	 * combined with the passed variadic arguements.
	 *
	 * Params:
	 * cond = The $(D bool) value indicating if the message should be logged.
	 * msg = The message that should be logged.
	 * a = The format arguments that will be used to printf style formatting.
	
	 *
	 * Returns: The logger used for by the logging member function * 
	 * 
	 * Examples:
	 * --------------------
	 * someLogger.logFatalF(someBoolValue, Hello %s, "World");
	 * --------------------
	 */
	void logFatalF(int line = __LINE__, string file = __FILE__, string funcName = __FUNCTION__, string prettyFuncName = __PRETTY_FUNCTION__, A...)(bool cond, string msg, A a) {
			this.logMessage(file, line, funcName, prettyFuncName, LogLevel.fatal, cond, format(msg, a));
	}
	
	/**
	 * This member function logs a string message in a printf like fashion depending on a condition with log level this.logLevel_.
	 *
	 * This member function takes a $(D LogLevel) as first argument. In
	 * addition to the $(D bool) value passed the passed $(D LogLevel)
	 * determines if the message is logged.  The second argument is a $(D
	 * bool) value. If the value is $(D true) the message will be logged
	 * solely depending on its $(D LogLevel). If the value is $(D false) the
	 * message will ot be logged. In order for the message to be processed the
	 * $(D LogLevel) must be greater equal to the $(D LogLevel) of the used
	 * logger and the global $(D LogLevel).The log message can contain printf
	 * style format sequences that will be combined with the passed variadic
	 * arguements.
	 *
	 * Params:
	 * cond = The $(D bool) value indicating if the message should be logged.
	 * logLevel = The $(D LogLevel) of the message.
	 * msg = The message that should be logged.
	 * a = The format arguments that will be used to printf style formatting.
	
	 *
	 * Returns: The logger used for by the logging member function * 
	 * 
	 * Examples:
	 * --------------------
	 * someLogger.logF(someLogLevel, someBoolValue, Hello %s, "World");
	 * --------------------
	 */
	void logF(int line = __LINE__, string file = __FILE__, string funcName = __FUNCTION__, string prettyFuncName = __PRETTY_FUNCTION__, A...)(const LogLevel logLevel, bool cond, string msg, A a) {
			this.logMessage(file, line, funcName, prettyFuncName, logLevel, cond, format(msg, a));
	}
	
	/**
	 * This member function logs a string message in a printf like fashion with log level this.logLevel_.
	 *
	 * This member function takes a $(D LogLevel) as first argument. In order
	 * for the message to be processed the $(D LogLevel) must be greater equal
	 * to the $(D LogLevel) of the used logger and the global $(D
	 * LogLevel).The log message can contain printf style format sequences
	 * that will be combined with the passed variadic arguements.
	 *
	 * Params:
	 * logLevel = The $(D LogLevel) of the message.
	 * msg = The message that should be logged.
	 * a = The format arguments that will be used to printf style formatting.
	
	 *
	 * Returns: The logger used for by the logging member function * 
	 * 
	 * Examples:
	 * --------------------
	 * someLogger.logF(someLogLevel, Hello %s, "World");
	 * --------------------
	 */
	void logF(int line = __LINE__, string file = __FILE__, string funcName = __FUNCTION__, string prettyFuncName = __PRETTY_FUNCTION__, A...)(const LogLevel logLevel, string msg, A a) {
			this.logMessage(file, line, funcName, prettyFuncName, logLevel, true, format(msg, a));
	}
	
	/**
	 * This member function logs a string message depending on a condition with log level this.logLevel_.
	 *
	 * This member function takes a $(D LogLevel) as first argument. In
	 * addition to the $(D bool) value passed the passed $(D LogLevel)
	 * determines if the message is logged.  The second argument is a $(D
	 * bool) value. If the value is $(D true) the message will be logged
	 * solely depending on its $(D LogLevel). If the value is $(D false) the
	 * message will ot be logged. In order for the message to be processed the
	 * $(D LogLevel) must be greater equal to the $(D LogLevel) of the used
	 * logger and the global $(D LogLevel).
	 *
	 * Params:
	 * cond = The $(D bool) value indicating if the message should be logged.
	 * logLevel = The $(D LogLevel) of the message.
	 * msg = The message that should be logged.
	
	 *
	 * Returns: The logger used for by the logging member function * 
	 * 
	 * Examples:
	 * --------------------
	 * someLogger.log(someLogLevel, someBoolValue, Hello World);
	 * --------------------
	 */
	void log(const LogLevel logLevel, bool cond, string msg = "", int line = __LINE__, string file = __FILE__, string funcName = __FUNCTION__, string prettyFuncName = __PRETTY_FUNCTION__) {
			this.logMessage(file, line, funcName, prettyFuncName, logLevel, cond, msg);
	}
	
	/**
	 * This member function logs a string message with log level this.logLevel_.
	 *
	 * This member function takes a $(D LogLevel) as first argument. In order
	 * for the message to be processed the $(D LogLevel) must be greater equal
	 * to the $(D LogLevel) of the used logger and the global $(D LogLevel).
	 *
	 * Params:
	 * logLevel = The $(D LogLevel) of the message.
	 * msg = The message that should be logged.
	
	 *
	 * Returns: The logger used for by the logging member function * 
	 * 
	 * Examples:
	 * --------------------
	 * someLogger.log(someLogLevel, Hello World);
	 * --------------------
	 */
	void log(const LogLevel logLevel, string msg = "", int line = __LINE__, string file = __FILE__, string funcName = __FUNCTION__, string prettyFuncName = __PRETTY_FUNCTION__) {
			this.logMessage(file, line, funcName, prettyFuncName, logLevel, true, msg);
	}

	//pragma(msg,buildLogFunction(true, false, false, false, LogLevel.unspecific));
	//pragma(msg,buildLogFunction(true, false, false, false, LogLevel.info));
	//pragma(msg,buildLogFunction(true, false, false, false, LogLevel.warning));
	//pragma(msg,buildLogFunction(true, false, false, false, LogLevel.error));
	//pragma(msg,buildLogFunction(true, false, false, false, LogLevel.critical));
	//pragma(msg,buildLogFunction(true, false, false, false, LogLevel.fatal));
	//pragma(msg,buildLogFunction(true, false, true, false, LogLevel.unspecific));
	//pragma(msg,buildLogFunction(true, false, true, false, LogLevel.info));
	//pragma(msg,buildLogFunction(true, false, true, false, LogLevel.warning));
	//pragma(msg,buildLogFunction(true, false, true, false, LogLevel.error));
	//pragma(msg,buildLogFunction(true, false, true, false, LogLevel.critical));
	//pragma(msg,buildLogFunction(true, false, true, false, LogLevel.fatal));
	//pragma(msg,buildLogFunction(true, true, false, false, LogLevel.unspecific));
	//pragma(msg,buildLogFunction(true, true, false, false, LogLevel.info));
	//pragma(msg,buildLogFunction(true, true, false, false, LogLevel.warning));
	//pragma(msg,buildLogFunction(true, true, false, false, LogLevel.error));
	//pragma(msg,buildLogFunction(true, true, false, false, LogLevel.critical));
	//pragma(msg,buildLogFunction(true, true, false, false, LogLevel.fatal));
	//pragma(msg,buildLogFunction(true, true, true, false, LogLevel.unspecific));
	//pragma(msg,buildLogFunction(true, true, true, false, LogLevel.info));
	//pragma(msg,buildLogFunction(true, true, true, false, LogLevel.warning));
	//pragma(msg,buildLogFunction(true, true, true, false, LogLevel.error));
	//pragma(msg,buildLogFunction(true, true, true, false, LogLevel.critical));
	//pragma(msg,buildLogFunction(true, true, true, false, LogLevel.fatal));
	//pragma(msg,buildLogFunction(true, true, true, true, LogLevel.unspecific));
	//pragma(msg,buildLogFunction(true, false, true, true, LogLevel.unspecific));
	//pragma(msg,buildLogFunction(true, true, false, true, LogLevel.unspecific));
	//pragma(msg,buildLogFunction(true, false, false, true, LogLevel.unspecific));

    private LogLevel logLevel_ = LogLevel.info;
    private string name_;
}

/** This $(D Logger) implementation writes log messages to the systems
standard output. The format of the output is:
$(D FileNameWithoutPath:FunctionNameWithoutModulePath:LineNumber Message).
*/
class StdIOLogger : Logger
{
	public this(const LogLevel lv = LogLevel.info) 
	{
		super(lv);
	}

    public override void writeLogMsg(LoggerPayload payload)
    {
        auto fnIdx = payload.file.lastIndexOf('/');
        fnIdx = fnIdx == -1 ? 0 : fnIdx+1;
        auto funIdx = payload.funcName.lastIndexOf('.');
        funIdx = funIdx == -1 ? 0 : funIdx+1;
        writefln("%s:%s:%u %s",payload.file[fnIdx .. $] ,
            payload.funcName[funIdx .. $], payload.line, payload.msg);
    }
}

/** This $(D Logger) implementation writes log messages to the associated
file. The name of the file has to be passed on construction time. If the file
is already present new log messages will be append at its end.
*/
class FileLogger : Logger
{
    public this(const string fn, const LogLevel lv = LogLevel.info)
    {
        super(lv);
        this.filename = fn;
        this.file_ = File(this.filename, "a");
    }

    /** When the $(D Logger) is no longer needed a call to this method
    releases the file.
    */
    public ~this()
    {
        if (file_.isOpen()) {
            file_.close();
        }
    }

    /** The messages written to file have the format of:
    $(D FileNameWithoutPath:FunctionNameWithoutModulePath:LineNumber Message).
    */
    public override void writeLogMsg(LoggerPayload payload)
    {
        size_t fnIdx = payload.file.lastIndexOf('/');
        fnIdx = fnIdx == -1 ? 0 : fnIdx+1;
        size_t funIdx = payload.funcName.lastIndexOf('.');
        funIdx = funIdx == -1 ? 0 : funIdx+1;
        this.file.writefln("%s:%s:%u %s",payload.file[fnIdx .. $] ,
            payload.funcName[funIdx .. $], payload.line, payload.msg);
    }

    /** The file written to is accessible by this method. */
    public @property File file()
    {
        return this.file_;
    }

    private File file_;
    private string filename;
}

/** MultiLogger logs to multiple logger.
*/
class MultiLogger : Logger 
{
	public this(const LogLevel lv = LogLevel.info) 
	{
		super(lv);
	}

    private Logger[string] logger;

	/** Insert a new Logger into the Multilogger.
	*/
    public void insertLogger(Logger newLogger) 
    {
        if (newLogger.name in logger) 
        {
            throw new Exception("This MultiLogger instance already holds a" 
                ~ " Logger named '%s'".format(newLogger.name));
        } 
        else 
        {
            logger[newLogger.name] = newLogger;
        }
    }

	/** Remove a Logger from the Multilogger.
	*/
    public Logger removeLogger(string loggerName)
    {
        if (loggerName !in logger)
        {
            throw new Exception("This MultiLogger instance does not hold a" 
                ~ " Logger named '%s'".format(loggerName));
        }
        else
        {
            Logger ret = logger[loggerName];
            logger.remove(loggerName);
            return ret;
        }
    }

    public override void writeLogMsg(LoggerPayload payload) {
        foreach (it; logger) 
        {
            it.writeLogMsg(payload);
        }
    }
}

/** The static $(D LogManager) handles the creation and the release of
instances of the $(D Logger) class. It also handels the $(I defaultLogger)
which is used if no logger is manually selected. Additionally the
$(D LogManager) also allows to retrieve $(D Logger) by there name.
An $(D StdIOLogger) is assigned to be the default $(D Logger).
*/
static class LogManager {
    private static this()
    {
        LogManager.defaultLogger_ = new StdIOLogger();
		LogManager.globalLogLevel_ = LogLevel.info;
    }

    // You must not instantiate a LogManager
    @disable private this() {}

    /** This method returns the default $(D Logger). */
    public @property final static ref Logger defaultLogger()
    {
        return LogManager.defaultLogger_;
    }

    /** This method returns the global $(D LogLevel). */
    public static @property LogLevel globalLogLevel()
    {
        return LogManager.globalLogLevel_;
    }

    /** This method sets the global $(D LogLevel). */
    public static @property void globalLogLevel(LogLevel ll)
    {
        LogManager.globalLogLevel_ = ll;
    }

    private static Logger defaultLogger_;
    private static LogLevel globalLogLevel_;
}

/+
/** This function returns a reference to the default logger. This
reference can be assigned a new logger, that will than act as the default
logger.*/
public ref Logger log() 
{
    return LogManager.defaultLogger;
}+/


/**
 * This function logs a string message .
 *
 * This function takes the log message as first argument. The $(D LogLevel) of the message is $(D this.logLevel_). In order for the message to be processed the $(D LogLevel) must be greater equal to the $(D LogLevel) of the used logger and the global $(D LogLevel).
 *
 * Params:
 * msg = The message that should be logged.
 * 
 * 
 * Examples:
 * --------------------
 * log(Hello World);
 * --------------------
 */
public ref Logger log(string msg = "", int line = __LINE__, string file = __FILE__, string funcName = __FUNCTION__, string prettyFuncName = __PRETTY_FUNCTION__) {
	LogManager.defaultLogger.log(LogManager.globalLogLevel, true, msg, line, file, funcName, prettyFuncName);
	return LogManager.defaultLogger;
}

/**
 * This function logs a string message .
 *
 * This function takes the log message as first argument. The $(D LogLevel) of the message is $(D LogLevel.info). In order for the message to be processed the $(D LogLevel) must be greater equal to the $(D LogLevel) of the used logger and the global $(D LogLevel).
 *
 * Params:
 * msg = The message that should be logged.
 * 
 * 
 * Examples:
 * --------------------
 * logInfo(Hello World);
 * --------------------
 */
public ref Logger logInfo(string msg = "", int line = __LINE__, string file = __FILE__, string funcName = __FUNCTION__, string prettyFuncName = __PRETTY_FUNCTION__) {
	LogManager.defaultLogger.log(LogLevel.info, true, msg, line, file, funcName, prettyFuncName);
	return LogManager.defaultLogger;
}

/**
 * This function logs a string message .
 *
 * This function takes the log message as first argument. The $(D LogLevel) of the message is $(D LogLevel.warning). In order for the message to be processed the $(D LogLevel) must be greater equal to the $(D LogLevel) of the used logger and the global $(D LogLevel).
 *
 * Params:
 * msg = The message that should be logged.
 * 
 * 
 * Examples:
 * --------------------
 * logWarning(Hello World);
 * --------------------
 */
public ref Logger logWarning(string msg = "", int line = __LINE__, string file = __FILE__, string funcName = __FUNCTION__, string prettyFuncName = __PRETTY_FUNCTION__) {
	LogManager.defaultLogger.log(LogLevel.warning, true, msg, line, file, funcName, prettyFuncName);
	return LogManager.defaultLogger;
}

/**
 * This function logs a string message .
 *
 * This function takes the log message as first argument. The $(D LogLevel) of the message is $(D LogLevel.error). In order for the message to be processed the $(D LogLevel) must be greater equal to the $(D LogLevel) of the used logger and the global $(D LogLevel).
 *
 * Params:
 * msg = The message that should be logged.
 * 
 * 
 * Examples:
 * --------------------
 * logError(Hello World);
 * --------------------
 */
public ref Logger logError(string msg = "", int line = __LINE__, string file = __FILE__, string funcName = __FUNCTION__, string prettyFuncName = __PRETTY_FUNCTION__) {
	LogManager.defaultLogger.log(LogLevel.error, true, msg, line, file, funcName, prettyFuncName);
	return LogManager.defaultLogger;
}

/**
 * This function logs a string message .
 *
 * This function takes the log message as first argument. The $(D LogLevel) of the message is $(D LogLevel.critical). In order for the message to be processed the $(D LogLevel) must be greater equal to the $(D LogLevel) of the used logger and the global $(D LogLevel).
 *
 * Params:
 * msg = The message that should be logged.
 * 
 * 
 * Examples:
 * --------------------
 * logCritical(Hello World);
 * --------------------
 */
public ref Logger logCritical(string msg = "", int line = __LINE__, string file = __FILE__, string funcName = __FUNCTION__, string prettyFuncName = __PRETTY_FUNCTION__) {
	LogManager.defaultLogger.log(LogLevel.critical, true, msg, line, file, funcName, prettyFuncName);
	return LogManager.defaultLogger;
}

/**
 * This function logs a string message .
 *
 * This function takes the log message as first argument. The $(D LogLevel) of the message is $(D LogLevel.fatal). In order for the message to be processed the $(D LogLevel) must be greater equal to the $(D LogLevel) of the used logger and the global $(D LogLevel).
 *
 * Params:
 * msg = The message that should be logged.
 * 
 * 
 * Examples:
 * --------------------
 * logFatal(Hello World);
 * --------------------
 */
public ref Logger logFatal(string msg = "", int line = __LINE__, string file = __FILE__, string funcName = __FUNCTION__, string prettyFuncName = __PRETTY_FUNCTION__) {
	LogManager.defaultLogger.log(LogLevel.fatal, true, msg, line, file, funcName, prettyFuncName);
	return LogManager.defaultLogger;
}

/**
 * This function logs a string message in a printf like fashion .
 *
 * This function takes the log message as first argument. The $(D LogLevel) of the message is $(D this.logLevel_). In order for the message to be processed the $(D LogLevel) must be greater equal to the $(D LogLevel) of the used logger and the global $(D LogLevel).The log message can contain printf style format sequences that will be combined with the passed variadic arguements.
 *
 * Params:
 * msg = The message that should be logged.
 * a = The format arguments that will be used to printf style formatting.
 * 
 * 
 * Examples:
 * --------------------
 * logF(Hello %s, "World");
 * --------------------
 */
public ref Logger logF(int line = __LINE__, string file = __FILE__, string funcName = __FUNCTION__, string prettyFuncName = __PRETTY_FUNCTION__, A...)(string msg, A a) {
	LogManager.defaultLogger.log(LogManager.globalLogLevel, true, format(msg, a), line, file, funcName, prettyFuncName);
	return LogManager.defaultLogger;
}

/**
 * This function logs a string message in a printf like fashion .
 *
 * This function takes the log message as first argument. The $(D LogLevel) of the message is $(D LogLevel.info). In order for the message to be processed the $(D LogLevel) must be greater equal to the $(D LogLevel) of the used logger and the global $(D LogLevel).The log message can contain printf style format sequences that will be combined with the passed variadic arguements.
 *
 * Params:
 * msg = The message that should be logged.
 * a = The format arguments that will be used to printf style formatting.
 * 
 * 
 * Examples:
 * --------------------
 * logInfoF(Hello %s, "World");
 * --------------------
 */
public ref Logger logInfoF(int line = __LINE__, string file = __FILE__, string funcName = __FUNCTION__, string prettyFuncName = __PRETTY_FUNCTION__, A...)(string msg, A a) {
	LogManager.defaultLogger.log(LogLevel.info, true, format(msg, a), line, file, funcName, prettyFuncName);
	return LogManager.defaultLogger;
}

/**
 * This function logs a string message in a printf like fashion .
 *
 * This function takes the log message as first argument. The $(D LogLevel) of the message is $(D LogLevel.warning). In order for the message to be processed the $(D LogLevel) must be greater equal to the $(D LogLevel) of the used logger and the global $(D LogLevel).The log message can contain printf style format sequences that will be combined with the passed variadic arguements.
 *
 * Params:
 * msg = The message that should be logged.
 * a = The format arguments that will be used to printf style formatting.
 * 
 * 
 * Examples:
 * --------------------
 * logWarningF(Hello %s, "World");
 * --------------------
 */
public ref Logger logWarningF(int line = __LINE__, string file = __FILE__, string funcName = __FUNCTION__, string prettyFuncName = __PRETTY_FUNCTION__, A...)(string msg, A a) {
	LogManager.defaultLogger.log(LogLevel.warning, true, format(msg, a), line, file, funcName, prettyFuncName);
	return LogManager.defaultLogger;
}

/**
 * This function logs a string message in a printf like fashion .
 *
 * This function takes the log message as first argument. The $(D LogLevel) of the message is $(D LogLevel.error). In order for the message to be processed the $(D LogLevel) must be greater equal to the $(D LogLevel) of the used logger and the global $(D LogLevel).The log message can contain printf style format sequences that will be combined with the passed variadic arguements.
 *
 * Params:
 * msg = The message that should be logged.
 * a = The format arguments that will be used to printf style formatting.
 * 
 * 
 * Examples:
 * --------------------
 * logErrorF(Hello %s, "World");
 * --------------------
 */
public ref Logger logErrorF(int line = __LINE__, string file = __FILE__, string funcName = __FUNCTION__, string prettyFuncName = __PRETTY_FUNCTION__, A...)(string msg, A a) {
	LogManager.defaultLogger.log(LogLevel.error, true, format(msg, a), line, file, funcName, prettyFuncName);
	return LogManager.defaultLogger;
}

/**
 * This function logs a string message in a printf like fashion .
 *
 * This function takes the log message as first argument. The $(D LogLevel) of the message is $(D LogLevel.critical). In order for the message to be processed the $(D LogLevel) must be greater equal to the $(D LogLevel) of the used logger and the global $(D LogLevel).The log message can contain printf style format sequences that will be combined with the passed variadic arguements.
 *
 * Params:
 * msg = The message that should be logged.
 * a = The format arguments that will be used to printf style formatting.
 * 
 * 
 * Examples:
 * --------------------
 * logCriticalF(Hello %s, "World");
 * --------------------
 */
public ref Logger logCriticalF(int line = __LINE__, string file = __FILE__, string funcName = __FUNCTION__, string prettyFuncName = __PRETTY_FUNCTION__, A...)(string msg, A a) {
	LogManager.defaultLogger.log(LogLevel.critical, true, format(msg, a), line, file, funcName, prettyFuncName);
	return LogManager.defaultLogger;
}

/**
 * This function logs a string message in a printf like fashion .
 *
 * This function takes the log message as first argument. The $(D LogLevel) of the message is $(D LogLevel.fatal). In order for the message to be processed the $(D LogLevel) must be greater equal to the $(D LogLevel) of the used logger and the global $(D LogLevel).The log message can contain printf style format sequences that will be combined with the passed variadic arguements.
 *
 * Params:
 * msg = The message that should be logged.
 * a = The format arguments that will be used to printf style formatting.
 * 
 * 
 * Examples:
 * --------------------
 * logFatalF(Hello %s, "World");
 * --------------------
 */
public ref Logger logFatalF(int line = __LINE__, string file = __FILE__, string funcName = __FUNCTION__, string prettyFuncName = __PRETTY_FUNCTION__, A...)(string msg, A a) {
	LogManager.defaultLogger.log(LogLevel.fatal, true, format(msg, a), line, file, funcName, prettyFuncName);
	return LogManager.defaultLogger;
}

/**
 * This function logs a string message depending on a condition .
 *
 * This function takes a $(D bool) as first argument. If the value is $(D true) the message will be logged solely depending on its $(D LogLevel). If the value is $(D false) the message will ot be logged. The $(D LogLevel) of the message is $(D this.logLevel_). In order for the message to be processed the $(D LogLevel) must be greater equal to the $(D LogLevel) of the used logger and the global $(D LogLevel).
 *
 * Params:
 * cond = The $(D bool) value indicating if the message should be logged.
 * msg = The message that should be logged.
 * 
 * 
 * Examples:
 * --------------------
 * log(someBoolValue, Hello World);
 * --------------------
 */
public ref Logger log(bool cond, string msg = "", int line = __LINE__, string file = __FILE__, string funcName = __FUNCTION__, string prettyFuncName = __PRETTY_FUNCTION__) {
	LogManager.defaultLogger.log(LogManager.globalLogLevel, cond, msg, line, file, funcName, prettyFuncName);
	return LogManager.defaultLogger;
}

/**
 * This function logs a string message depending on a condition .
 *
 * This function takes a $(D bool) as first argument. If the value is $(D true) the message will be logged solely depending on its $(D LogLevel). If the value is $(D false) the message will ot be logged. The $(D LogLevel) of the message is $(D LogLevel.info). In order for the message to be processed the $(D LogLevel) must be greater equal to the $(D LogLevel) of the used logger and the global $(D LogLevel).
 *
 * Params:
 * cond = The $(D bool) value indicating if the message should be logged.
 * msg = The message that should be logged.
 * 
 * 
 * Examples:
 * --------------------
 * logInfo(someBoolValue, Hello World);
 * --------------------
 */
public ref Logger logInfo(bool cond, string msg = "", int line = __LINE__, string file = __FILE__, string funcName = __FUNCTION__, string prettyFuncName = __PRETTY_FUNCTION__) {
	LogManager.defaultLogger.log(LogLevel.info, cond, msg, line, file, funcName, prettyFuncName);
	return LogManager.defaultLogger;
}

/**
 * This function logs a string message depending on a condition .
 *
 * This function takes a $(D bool) as first argument. If the value is $(D true) the message will be logged solely depending on its $(D LogLevel). If the value is $(D false) the message will ot be logged. The $(D LogLevel) of the message is $(D LogLevel.warning). In order for the message to be processed the $(D LogLevel) must be greater equal to the $(D LogLevel) of the used logger and the global $(D LogLevel).
 *
 * Params:
 * cond = The $(D bool) value indicating if the message should be logged.
 * msg = The message that should be logged.
 * 
 * 
 * Examples:
 * --------------------
 * logWarning(someBoolValue, Hello World);
 * --------------------
 */
public ref Logger logWarning(bool cond, string msg = "", int line = __LINE__, string file = __FILE__, string funcName = __FUNCTION__, string prettyFuncName = __PRETTY_FUNCTION__) {
	LogManager.defaultLogger.log(LogLevel.warning, cond, msg, line, file, funcName, prettyFuncName);
	return LogManager.defaultLogger;
}

/**
 * This function logs a string message depending on a condition .
 *
 * This function takes a $(D bool) as first argument. If the value is $(D true) the message will be logged solely depending on its $(D LogLevel). If the value is $(D false) the message will ot be logged. The $(D LogLevel) of the message is $(D LogLevel.error). In order for the message to be processed the $(D LogLevel) must be greater equal to the $(D LogLevel) of the used logger and the global $(D LogLevel).
 *
 * Params:
 * cond = The $(D bool) value indicating if the message should be logged.
 * msg = The message that should be logged.
 * 
 * 
 * Examples:
 * --------------------
 * logError(someBoolValue, Hello World);
 * --------------------
 */
public ref Logger logError(bool cond, string msg = "", int line = __LINE__, string file = __FILE__, string funcName = __FUNCTION__, string prettyFuncName = __PRETTY_FUNCTION__) {
	LogManager.defaultLogger.log(LogLevel.error, cond, msg, line, file, funcName, prettyFuncName);
	return LogManager.defaultLogger;
}

/**
 * This function logs a string message depending on a condition .
 *
 * This function takes a $(D bool) as first argument. If the value is $(D true) the message will be logged solely depending on its $(D LogLevel). If the value is $(D false) the message will ot be logged. The $(D LogLevel) of the message is $(D LogLevel.critical). In order for the message to be processed the $(D LogLevel) must be greater equal to the $(D LogLevel) of the used logger and the global $(D LogLevel).
 *
 * Params:
 * cond = The $(D bool) value indicating if the message should be logged.
 * msg = The message that should be logged.
 * 
 * 
 * Examples:
 * --------------------
 * logCritical(someBoolValue, Hello World);
 * --------------------
 */
public ref Logger logCritical(bool cond, string msg = "", int line = __LINE__, string file = __FILE__, string funcName = __FUNCTION__, string prettyFuncName = __PRETTY_FUNCTION__) {
	LogManager.defaultLogger.log(LogLevel.critical, cond, msg, line, file, funcName, prettyFuncName);
	return LogManager.defaultLogger;
}

/**
 * This function logs a string message depending on a condition .
 *
 * This function takes a $(D bool) as first argument. If the value is $(D true) the message will be logged solely depending on its $(D LogLevel). If the value is $(D false) the message will ot be logged. The $(D LogLevel) of the message is $(D LogLevel.fatal). In order for the message to be processed the $(D LogLevel) must be greater equal to the $(D LogLevel) of the used logger and the global $(D LogLevel).
 *
 * Params:
 * cond = The $(D bool) value indicating if the message should be logged.
 * msg = The message that should be logged.
 * 
 * 
 * Examples:
 * --------------------
 * logFatal(someBoolValue, Hello World);
 * --------------------
 */
public ref Logger logFatal(bool cond, string msg = "", int line = __LINE__, string file = __FILE__, string funcName = __FUNCTION__, string prettyFuncName = __PRETTY_FUNCTION__) {
	LogManager.defaultLogger.log(LogLevel.fatal, cond, msg, line, file, funcName, prettyFuncName);
	return LogManager.defaultLogger;
}

/**
 * This function logs a string message in a printf like fashion depending on a condition .
 *
 * This function takes a $(D bool) as first argument. If the value is $(D true) the message will be logged solely depending on its $(D LogLevel). If the value is $(D false) the message will ot be logged. The $(D LogLevel) of the message is $(D this.logLevel_). In order for the message to be processed the $(D LogLevel) must be greater equal to the $(D LogLevel) of the used logger and the global $(D LogLevel).The log message can contain printf style format sequences that will be combined with the passed variadic arguements.
 *
 * Params:
 * cond = The $(D bool) value indicating if the message should be logged.
 * msg = The message that should be logged.
 * a = The format arguments that will be used to printf style formatting.
 * 
 * 
 * Examples:
 * --------------------
 * logF(someBoolValue, Hello %s, "World");
 * --------------------
 */
public ref Logger logF(int line = __LINE__, string file = __FILE__, string funcName = __FUNCTION__, string prettyFuncName = __PRETTY_FUNCTION__, A...)(bool cond, string msg, A a) {
	LogManager.defaultLogger.log(LogManager.globalLogLevel, cond, format(msg, a), line, file, funcName, prettyFuncName);
	return LogManager.defaultLogger;
}

/**
 * This function logs a string message in a printf like fashion depending on a condition .
 *
 * This function takes a $(D bool) as first argument. If the value is $(D true) the message will be logged solely depending on its $(D LogLevel). If the value is $(D false) the message will ot be logged. The $(D LogLevel) of the message is $(D LogLevel.info). In order for the message to be processed the $(D LogLevel) must be greater equal to the $(D LogLevel) of the used logger and the global $(D LogLevel).The log message can contain printf style format sequences that will be combined with the passed variadic arguements.
 *
 * Params:
 * cond = The $(D bool) value indicating if the message should be logged.
 * msg = The message that should be logged.
 * a = The format arguments that will be used to printf style formatting.
 * 
 * 
 * Examples:
 * --------------------
 * logInfoF(someBoolValue, Hello %s, "World");
 * --------------------
 */
public ref Logger logInfoF(int line = __LINE__, string file = __FILE__, string funcName = __FUNCTION__, string prettyFuncName = __PRETTY_FUNCTION__, A...)(bool cond, string msg, A a) {
	LogManager.defaultLogger.log(LogLevel.info, cond, format(msg, a), line, file, funcName, prettyFuncName);
	return LogManager.defaultLogger;
}

/**
 * This function logs a string message in a printf like fashion depending on a condition .
 *
 * This function takes a $(D bool) as first argument. If the value is $(D true) the message will be logged solely depending on its $(D LogLevel). If the value is $(D false) the message will ot be logged. The $(D LogLevel) of the message is $(D LogLevel.warning). In order for the message to be processed the $(D LogLevel) must be greater equal to the $(D LogLevel) of the used logger and the global $(D LogLevel).The log message can contain printf style format sequences that will be combined with the passed variadic arguements.
 *
 * Params:
 * cond = The $(D bool) value indicating if the message should be logged.
 * msg = The message that should be logged.
 * a = The format arguments that will be used to printf style formatting.
 * 
 * 
 * Examples:
 * --------------------
 * logWarningF(someBoolValue, Hello %s, "World");
 * --------------------
 */
public ref Logger logWarningF(int line = __LINE__, string file = __FILE__, string funcName = __FUNCTION__, string prettyFuncName = __PRETTY_FUNCTION__, A...)(bool cond, string msg, A a) {
	LogManager.defaultLogger.log(LogLevel.warning, cond, format(msg, a), line, file, funcName, prettyFuncName);
	return LogManager.defaultLogger;
}

/**
 * This function logs a string message in a printf like fashion depending on a condition .
 *
 * This function takes a $(D bool) as first argument. If the value is $(D true) the message will be logged solely depending on its $(D LogLevel). If the value is $(D false) the message will ot be logged. The $(D LogLevel) of the message is $(D LogLevel.error). In order for the message to be processed the $(D LogLevel) must be greater equal to the $(D LogLevel) of the used logger and the global $(D LogLevel).The log message can contain printf style format sequences that will be combined with the passed variadic arguements.
 *
 * Params:
 * cond = The $(D bool) value indicating if the message should be logged.
 * msg = The message that should be logged.
 * a = The format arguments that will be used to printf style formatting.
 * 
 * 
 * Examples:
 * --------------------
 * logErrorF(someBoolValue, Hello %s, "World");
 * --------------------
 */
public ref Logger logErrorF(int line = __LINE__, string file = __FILE__, string funcName = __FUNCTION__, string prettyFuncName = __PRETTY_FUNCTION__, A...)(bool cond, string msg, A a) {
	LogManager.defaultLogger.log(LogLevel.error, cond, format(msg, a), line, file, funcName, prettyFuncName);
	return LogManager.defaultLogger;
}

/**
 * This function logs a string message in a printf like fashion depending on a condition .
 *
 * This function takes a $(D bool) as first argument. If the value is $(D true) the message will be logged solely depending on its $(D LogLevel). If the value is $(D false) the message will ot be logged. The $(D LogLevel) of the message is $(D LogLevel.critical). In order for the message to be processed the $(D LogLevel) must be greater equal to the $(D LogLevel) of the used logger and the global $(D LogLevel).The log message can contain printf style format sequences that will be combined with the passed variadic arguements.
 *
 * Params:
 * cond = The $(D bool) value indicating if the message should be logged.
 * msg = The message that should be logged.
 * a = The format arguments that will be used to printf style formatting.
 * 
 * 
 * Examples:
 * --------------------
 * logCriticalF(someBoolValue, Hello %s, "World");
 * --------------------
 */
public ref Logger logCriticalF(int line = __LINE__, string file = __FILE__, string funcName = __FUNCTION__, string prettyFuncName = __PRETTY_FUNCTION__, A...)(bool cond, string msg, A a) {
	LogManager.defaultLogger.log(LogLevel.critical, cond, format(msg, a), line, file, funcName, prettyFuncName);
	return LogManager.defaultLogger;
}

/**
 * This function logs a string message in a printf like fashion depending on a condition .
 *
 * This function takes a $(D bool) as first argument. If the value is $(D true) the message will be logged solely depending on its $(D LogLevel). If the value is $(D false) the message will ot be logged. The $(D LogLevel) of the message is $(D LogLevel.fatal). In order for the message to be processed the $(D LogLevel) must be greater equal to the $(D LogLevel) of the used logger and the global $(D LogLevel).The log message can contain printf style format sequences that will be combined with the passed variadic arguements.
 *
 * Params:
 * cond = The $(D bool) value indicating if the message should be logged.
 * msg = The message that should be logged.
 * a = The format arguments that will be used to printf style formatting.
 * 
 * 
 * Examples:
 * --------------------
 * logFatalF(someBoolValue, Hello %s, "World");
 * --------------------
 */
public ref Logger logFatalF(int line = __LINE__, string file = __FILE__, string funcName = __FUNCTION__, string prettyFuncName = __PRETTY_FUNCTION__, A...)(bool cond, string msg, A a) {
	LogManager.defaultLogger.log(LogLevel.fatal, cond, format(msg, a), line, file, funcName, prettyFuncName);
	return LogManager.defaultLogger;
}

/**
 * This function logs a string message in a printf like fashion depending on a condition with log level this.logLevel_.
 *
 * This function takes a $(D LogLevel) as first argument. In addition to the $(D bool) value passed the passed $(D LogLevel) determines if the message is logged.  The second argument is a $(D bool) value. If the value is $(D true) the message will be logged solely depending on its $(D LogLevel). If the value is $(D false) the message will ot be logged. In order for the message to be processed the $(D LogLevel) must be greater equal to the $(D LogLevel) of the used logger and the global $(D LogLevel).The log message can contain printf style format sequences that will be combined with the passed variadic arguements.
 *
 * Params:
 * cond = The $(D bool) value indicating if the message should be logged.
 * logLevel = The $(D LogLevel) of the message.
 * msg = The message that should be logged.
 * a = The format arguments that will be used to printf style formatting.
 * 
 * 
 * Examples:
 * --------------------
 * logF(someLogLevel, someBoolValue, Hello %s, "World");
 * --------------------
 */
public ref Logger logF(int line = __LINE__, string file = __FILE__, string funcName = __FUNCTION__, string prettyFuncName = __PRETTY_FUNCTION__, A...)(const LogLevel logLevel, bool cond, string msg, A a) {
	LogManager.defaultLogger.log(logLevel, cond, format(msg, a), line, file, funcName, prettyFuncName);
	return LogManager.defaultLogger;
}

/**
 * This function logs a string message in a printf like fashion with log level this.logLevel_.
 *
 * This function takes a $(D LogLevel) as first argument. In order for the message to be processed the $(D LogLevel) must be greater equal to the $(D LogLevel) of the used logger and the global $(D LogLevel).The log message can contain printf style format sequences that will be combined with the passed variadic arguements.
 *
 * Params:
 * logLevel = The $(D LogLevel) of the message.
 * msg = The message that should be logged.
 * a = The format arguments that will be used to printf style formatting.
 * 
 * 
 * Examples:
 * --------------------
 * logF(someLogLevel, Hello %s, "World");
 * --------------------
 */
public ref Logger logF(int line = __LINE__, string file = __FILE__, string funcName = __FUNCTION__, string prettyFuncName = __PRETTY_FUNCTION__, A...)(const LogLevel logLevel, string msg, A a) {
	LogManager.defaultLogger.log(logLevel, true, format(msg, a), line, file, funcName, prettyFuncName);
	return LogManager.defaultLogger;
}

/**
 * This function logs a string message depending on a condition with log level this.logLevel_.
 *
 * This function takes a $(D LogLevel) as first argument. In addition to the $(D bool) value passed the passed $(D LogLevel) determines if the message is logged.  The second argument is a $(D bool) value. If the value is $(D true) the message will be logged solely depending on its $(D LogLevel). If the value is $(D false) the message will ot be logged. In order for the message to be processed the $(D LogLevel) must be greater equal to the $(D LogLevel) of the used logger and the global $(D LogLevel).
 *
 * Params:
 * cond = The $(D bool) value indicating if the message should be logged.
 * logLevel = The $(D LogLevel) of the message.
 * msg = The message that should be logged.
 * 
 * 
 * Examples:
 * --------------------
 * log(someLogLevel, someBoolValue, Hello World);
 * --------------------
 */
public ref Logger log(const LogLevel logLevel, bool cond, string msg = "", int line = __LINE__, string file = __FILE__, string funcName = __FUNCTION__, string prettyFuncName = __PRETTY_FUNCTION__) {
	LogManager.defaultLogger.log(logLevel, cond, msg, line, file, funcName, prettyFuncName);
	return LogManager.defaultLogger;
}

/**
 * This function logs a string message with log level this.logLevel_.
 *
 * This function takes a $(D LogLevel) as first argument. In order for the message to be processed the $(D LogLevel) must be greater equal to the $(D LogLevel) of the used logger and the global $(D LogLevel).
 *
 * Params:
 * logLevel = The $(D LogLevel) of the message.
 * msg = The message that should be logged.
 * 
 * 
 * Examples:
 * --------------------
 * log(someLogLevel, Hello World);
 * --------------------
 */
public ref Logger log(const LogLevel logLevel, string msg = "", int line = __LINE__, string file = __FILE__, string funcName = __FUNCTION__, string prettyFuncName = __PRETTY_FUNCTION__) {
	LogManager.defaultLogger.log(logLevel, true, msg, line, file, funcName, prettyFuncName);
	return LogManager.defaultLogger;
}

//pragma(msg, buildLogFunction(false, false, false, false, LogLevel.unspecific));
//pragma(msg, buildLogFunction(false, false, false, false, LogLevel.unspecific));
//pragma(msg, buildLogFunction(false, false, false, false, LogLevel.info));
//pragma(msg, buildLogFunction(false, false, false, false, LogLevel.warning));
//pragma(msg, buildLogFunction(false, false, false, false, LogLevel.error));
//pragma(msg, buildLogFunction(false, false, false, false, LogLevel.critical));
//pragma(msg, buildLogFunction(false, false, false, false, LogLevel.fatal));
//pragma(msg, buildLogFunction(false, false, true, false, LogLevel.unspecific));
//pragma(msg, buildLogFunction(false, false, true, false, LogLevel.info));
//pragma(msg, buildLogFunction(false, false, true, false, LogLevel.warning));
//pragma(msg, buildLogFunction(false, false, true, false, LogLevel.error));
//pragma(msg, buildLogFunction(false, false, true, false, LogLevel.critical));
//pragma(msg, buildLogFunction(false, false, true, false, LogLevel.fatal));
//pragma(msg, buildLogFunction(false, true, false, false, LogLevel.unspecific));
//pragma(msg, buildLogFunction(false, true, false, false, LogLevel.info));
//pragma(msg, buildLogFunction(false, true, false, false, LogLevel.warning));
//pragma(msg, buildLogFunction(false, true, false, false, LogLevel.error));
//pragma(msg, buildLogFunction(false, true, false, false, LogLevel.critical));
//pragma(msg, buildLogFunction(false, true, false, false, LogLevel.fatal));
//pragma(msg, buildLogFunction(false, true, true, false, LogLevel.unspecific));
//pragma(msg, buildLogFunction(false, true, true, false, LogLevel.info));
//pragma(msg, buildLogFunction(false, true, true, false, LogLevel.warning));
//pragma(msg, buildLogFunction(false, true, true, false, LogLevel.error));
//pragma(msg, buildLogFunction(false, true, true, false, LogLevel.critical));
//pragma(msg, buildLogFunction(false, true, true, false, LogLevel.fatal));
//pragma(msg, buildLogFunction(false, true, true, true, LogLevel.unspecific));
//pragma(msg, buildLogFunction(false, false, true, true, LogLevel.unspecific));
//pragma(msg, buildLogFunction(false, true, false, true, LogLevel.unspecific));
//pragma(msg, buildLogFunction(false, false, false, true, LogLevel.unspecific));

unittest
{
    LogLevel ll = LogManager.globalLogLevel;
    LogManager.globalLogLevel = LogLevel.fatal;
    assert(LogManager.globalLogLevel == LogLevel.fatal);
    LogManager.globalLogLevel = ll;
}

version(unittest)
{
    class TestLogger : Logger
    {
        int line = -1;
        string file = null;
        string func = null;
        string prettyFunc = null;
        string msg = null;
        LogLevel lvl;

        public this(string n = "", const LogLevel lv = LogLevel.info)
        {
            super(n, lv);
        }

        public override void writeLogMsg(LoggerPayload payload)
        {
            this.line = payload.line;
            this.file = payload.file;
            this.func = payload.funcName;
            this.prettyFunc = payload.prettyFuncName;
            this.lvl = payload.logLevel;
            this.msg = payload.msg;
        }
    }
}

unittest
{
    auto tl1 = new TestLogger("one");
    auto tl2 = new TestLogger("two");

    auto ml = new MultiLogger();
    ml.insertLogger(tl1);
    ml.insertLogger(tl2);
    assertThrown!Exception(ml.insertLogger(tl1));

    string msg = "Hello Logger World";
    ml.log(msg);
    int lineNumber = __LINE__ - 1;
    assert(tl1.msg == msg);
    assert(tl1.line == lineNumber);
    assert(tl2.msg == msg);
    assert(tl2.line == lineNumber);

    ml.removeLogger(tl1.name);
    ml.removeLogger(tl2.name);
    assertThrown!Exception(ml.removeLogger(tl1.name));
}

unittest
{
    auto l = new TestLogger();
    string msg = "Hello Logger World";
    l.log(msg);
    int lineNumber = __LINE__ - 1;
    assert(l.msg == msg);
    assert(l.line == lineNumber);
    assert(l.logLevel == LogLevel.info);

    l.log(true, msg);
    lineNumber = __LINE__ - 1;
    assert(l.msg == msg);
    assert(l.line == lineNumber);
    assert(l.logLevel == LogLevel.info);

    l.log(false, msg);
    assert(l.msg == msg);
    assert(l.line == lineNumber);
    assert(l.logLevel == LogLevel.info);

    msg = "%s Another message";
    l.logF(msg, "Yet");
    lineNumber = __LINE__ - 1;
    assert(l.msg == msg.format("Yet"));
    assert(l.line == lineNumber);
    assert(l.logLevel == LogLevel.info);

    l.logF(true, msg, "Yet");
    lineNumber = __LINE__ - 1;
    assert(l.msg == msg.format("Yet"));
    assert(l.line == lineNumber);
    assert(l.logLevel == LogLevel.info);

    l.logF(false, msg, "Yet");
    int nLineNumber = __LINE__ - 1;
    assert(l.msg == msg.format("Yet"));
    assert(l.line == lineNumber);
    assert(l.logLevel == LogLevel.info);

    l.logF(LogLevel.fatal, msg, "Yet");
    lineNumber = __LINE__ - 1;
    assert(l.msg == msg.format("Yet"));
    assert(l.line == lineNumber);
    assert(l.logLevel == LogLevel.info);

    l.logF(LogLevel.fatal, true, msg, "Yet");
    lineNumber = __LINE__ - 1;
    assert(l.msg == msg.format("Yet"));
    assert(l.line == lineNumber);
    assert(l.logLevel == LogLevel.info);

    l.logF(LogLevel.fatal, false, msg, "Yet");
    nLineNumber = __LINE__ - 1;
    assert(l.msg == msg.format("Yet"));
    assert(l.line == lineNumber);
    assert(l.logLevel == LogLevel.info);

    auto oldunspecificLogger = log(false);
	assert(oldunspecificLogger.logLevel == LogLevel.info);
    log(false) = l;
	assert(log.logLevel == LogLevel.info);
	assert(LogManager.globalLogLevel == LogLevel.info,
			to!string(LogManager.globalLogLevel));

    scope(exit)
    {
        log = oldunspecificLogger;
    }

    msg = "Another message";
    log(msg);
    lineNumber = __LINE__ - 1;
    assert(l.logLevel == LogLevel.info);
    assert(l.line == lineNumber);
    assert(l.msg == msg, l.msg);

    log(true, msg);
    lineNumber = __LINE__ - 1;
    assert(l.msg == msg);
    assert(l.line == lineNumber);
    assert(l.logLevel == LogLevel.info);

    log(false, msg);
    assert(l.msg == msg);
    assert(l.line == lineNumber);
    assert(l.logLevel == LogLevel.info);

    msg = "%s Another message";
    logF(msg, "Yet");
    lineNumber = __LINE__ - 1;
    assert(l.msg == msg.format("Yet"));
    assert(l.line == lineNumber);
    assert(l.logLevel == LogLevel.info);

    logF(true, msg, "Yet");
    lineNumber = __LINE__ - 1;
    assert(l.msg == msg.format("Yet"));
    assert(l.line == lineNumber);
    assert(l.logLevel == LogLevel.info);

    logF(false, msg, "Yet");
    nLineNumber = __LINE__ - 1;
    assert(l.msg == msg.format("Yet"));
    assert(l.line == lineNumber);
    assert(l.logLevel == LogLevel.info);

    msg = "%s Another message";
    logF(LogLevel.fatal, msg, "Yet");
    lineNumber = __LINE__ - 1;
    assert(l.msg == msg.format("Yet"));
    assert(l.line == lineNumber);
    assert(l.logLevel == LogLevel.info);

    logF(LogLevel.fatal, true, msg, "Yet");
    lineNumber = __LINE__ - 1;
    assert(l.msg == msg.format("Yet"));
    assert(l.line == lineNumber);
    assert(l.logLevel == LogLevel.info);

    logF(LogLevel.fatal, false, msg, "Yet");
    nLineNumber = __LINE__ - 1;
    assert(l.msg == msg.format("Yet"));
    assert(l.line == lineNumber);
    assert(l.logLevel == LogLevel.info);
}

version(unittest)
{
    import std.array;
    import std.ascii;
    import std.random;

    string randomString(size_t upto)
    {
        auto app = Appender!string();
        foreach(_ ; 0 .. upto)
            app.put(letters[uniform(0, letters.length)]);
        return app.data;
    }
}

unittest // file logger test
{
    import std.file;
    import std.stdio;
    Mt19937 gen;
    string name = randomString(32);
    string filename = randomString(32) ~ ".tempLogFile";
    auto l = new FileLogger(filename);

    scope(exit)
    {
        remove(filename);
    }

    string notWritten = "this should not be written to file";
    string written = "this should be written to file";

    l.logLevel = LogLevel.critical;
    l.log(LogLevel.warning, notWritten);
    l.log(LogLevel.critical, written);

    l.file.flush();
    l.file.close();

    auto file = File(filename, "r");
    assert(!file.eof);

    string readLine = file.readln();
    assert(readLine.indexOf(written) != -1);
    assert(readLine.indexOf(notWritten) == -1);
    file.close();

    l = new FileLogger(filename);
    l.log(LogLevel.critical, false, notWritten);
    l.log(LogLevel.fatal, true, written);
    l.file.close();

    file = File(filename, "r");
    file.readln();
    readLine = file.readln();
    string nextFile = file.readln();
    assert(nextFile.empty, nextFile);
    assert(readLine.indexOf(written) != -1);
    assert(readLine.indexOf(notWritten) == -1);
}

unittest // default logger
{
    import std.file;
    Mt19937 gen;
    string name = randomString(32);
    string filename = randomString(32) ~ ".tempLogFile";
    FileLogger l = new FileLogger(filename);
    auto oldunspecificLogger = log(false);
    log(false) = l;

    scope(exit)
    {
        remove(filename);
        log = oldunspecificLogger;
    }

    string notWritten = "this should not be written to file";
    string written = "this should be written to file";

    l.logLevel = LogLevel.critical;
    log(LogLevel.warning, notWritten);
    log(LogLevel.critical, written);

    l.file.flush();
    l.file.close();

    auto file = File(filename, "r");
    assert(!file.eof);

    string readLine = file.readln();
    assert(readLine.indexOf(written) != -1);
    assert(readLine.indexOf(notWritten) == -1);
    file.close();

    l = new FileLogger(filename);
    log = l;
    log.logLevel = LogLevel.fatal;
    log(LogLevel.critical, false, notWritten);
    log(LogLevel.fatal, true, written);
    l.file.close();

    file = File(filename, "r");
    file.readln();
    readLine = file.readln();
    string nextFile = file.readln();
    assert(!nextFile.empty, nextFile);
    assert(nextFile.indexOf(written) != -1);
    assert(nextFile.indexOf(notWritten) == -1);
}
