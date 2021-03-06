function out = runtests(varargin)
%runtests Run unit tests
%   runtests runs all the test cases that can be found in the current directory
%   and summarizes the results in the Command Window.
%
%   Test cases can be found in the following places in the current directory:
%
%       * An M-file function whose name starts or ends with "test" or
%         "Test" and that returns no output arguments.
%
%       * An M-file function whose name starts or ends with "test" or
%         "Test" and that contains subfunction tests and uses the
%         initTestSuite script to return a TestSuite object.
%
%       * An M-file defining a subclass of TestCase.
%
%   runtests(dirname) runs all the test cases found in the specified directory.
%
%   runtests(packagename) runs all the test cases found in the specified
%   package. (This option requires R2009a or later).
%
%   runtests(mfilename) runs test cases found in the specified function or class
%   name. The function or class needs to be in the current directory or on the
%   MATLAB path.
%
%   runtests('mfilename:testname') runs the specific test case named 'testname'
%   found in the function or class 'name'.
%
%   Multiple directories or file names can be specified by passing multiple
%   names to runtests, as in runtests(name1, name2, ...) or
%   runtests({name1, name2, ...}, ...)
%
%   runtests(..., '-verbose') displays the name and result, result, and time
%   taken for each test case to the Command Window.
%
%   runtests(..., '-logfile', filename) directs the output of runtests to
%   the specified log file instead of to the Command Window.
%
%   runtests(..., '-xmlfile', filename) directs the output of runtests to
%   the specified xUnit-formatted XML log file instead of to the Command
%   Window.  This format is compatible with JUnit, and can be read by many
%   tools.
%
%   You can also pass a directory path instead of a file path to
%   '-xmlfile'. If you do this, an xml file will be created for each suite,
%   which Jenkins will be able to present more helpfully.
%
%   out = runtests(...) returns a logical value that is true if all the
%   tests passed.
%
%   Examples
%   --------
%   Find and run all the test cases in the current directory.
%
%       runtests
%
%   Find and run all the test cases in the current directory. Display more
%   detailed information to the Command Window as the test cases are run.
%
%       runtests -verbose
%
%   Save verbose runtests output to a log file.
%
%       runtests -verbose -logfile my_test_log.txt
%
%   Find and run all the test cases contained in the M-file myfunc.
%
%       runtests myfunc
%
%   Find and run all the test cases contained in the TestCase subclass
%   MyTestCase.
%
%       runtests MyTestCase
%
%   Run the test case named 'testFeature' contained in the M-file myfunc.
%
%       runtests myfunc:testFeature
%
%   Run all the tests in a specific directory.
%
%       runtests c:\Work\MyProject\tests
%
%   Run all the tests in two directories.
%
%       runtests c:\Work\MyProject\tests c:\Work\Book\tests

%   Steven L. Eddins
%   Copyright 2009-2010 The MathWorks, Inc.

verbose = false;
logfile = '';
xmlfile = '';
suppress = false;
if nargin < 1
    suite = TestSuite.fromPwd();
else
    [name_list, verbose, logfile, xmlfile, suppress] = getInputNames(varargin{:});
    if numel(name_list) == 0
        suite = TestSuite.fromPwd();
    elseif numel(name_list) == 1
        suite = TestSuite.fromName(name_list{1});
    else
        suite = TestSuite();
        for k = 1:numel(name_list)
            suite.add(TestSuite.fromName(name_list{k}));
        end
    end
end

if isempty(suite.TestComponents)
    error('xunit:runtests:noTestCasesFound', 'No test cases found.');
end

if(suppress && isempty(logfile) && isempty(xmlfile))
    error('xunit:runtests:noOutputFound', 'You should specify at least one way to get your test results.');
end

loggers = {};

if ~suppress % Display output to command line
    if verbose
        loggers{end+1} = {VerboseTestRunDisplay(1)};
    else
        loggers{end+1} = {TestRunDisplay(1)};
    end
end

if ~isempty(logfile) % Log output to a log file.
    logfile_handle = fopen(logfile, 'w');
    if logfile_handle < 0
        error('xunit:runtests:FileOpenFailed', ...
            'Could not open "%s" for writing.', logfile);
    else
        cleanup = onCleanup(@() fclose(logfile_handle));
    end
    
    if verbose
        loggers{end+1} = {VerboseTestRunDisplay(logfile_handle)};
    else
        loggers{end+1} = {TestRunDisplay(logfile_handle)};
    end

    fprintf(logfile_handle, 'Test suite: %s\n', suite.Name);
    if ~strcmp(suite.Name, suite.Location)
        fprintf(logfile_handle, 'Test suite location: %s\n', suite.Location);
    end
    fprintf(logfile_handle, '%s\n\n', datestr(now));
end

if ~isempty(xmlfile) % Create an xml file.
    loggers{end+1} = {XMLTestRunLogger(xmlfile)};
end

monitor = MetaTestRunLogger(loggers);
did_pass = suite.run(monitor);

if nargout > 0
    out = did_pass;
end

function [name_list, verbose, logfile, xmlfile, suppress] = getInputNames(varargin)
name_list = {};
verbose = false;
logfile = '';
xmlfile = '';
suppress = false;
k = 1;
while k <= numel(varargin)
    arg = varargin{k};
    if iscell(arg)
        name_list = [name_list; arg];
    elseif ~isempty(arg) && (arg(1) == '-')
        if strcmp(arg, '-verbose')
            verbose = true;
        elseif strcmp(arg, '-suppress')
            suppress = true;            
        elseif strcmp(arg, '-logfile')
            if k == numel(varargin)
                error('xunit:runtests:MissingLogfile', ...
                    'The option -logfile must be followed by a filename.');
            else
                logfile = varargin{k+1};
                k = k + 1;
            end
        elseif strcmp(arg, '-xmlfile')
            if k == numel(varargin)
                error('xunit:runtests:MissingXMLfile', ...
                    'The option -xmlfile must be followed by a filename.');
            else
                xmlfile = varargin{k+1};
                k = k + 1;
            end
        else
            warning('runtests:unrecognizedOption', 'Unrecognized option: %s', arg);
        end
    else
        name_list{end+1} = arg;
    end
    k = k + 1;
end
    
