function status = psom_run_pipeline(pipeline,opt)
% Run a pipeline.
%
% SYNTAX: status = psom_run_pipeline( pipeline , opt )
%
% _________________________________________________________________________
% INPUTS:
%
% PIPELINE
%    (structure) a matlab structure which defines a pipeline.
%    Each field name <JOB_NAME> will be used to name jobs of the
%    pipeline. The fields <JOB_NAME> are themselves structure, with the
%    following fields :
%
%    COMMAND
%        (string) the name of the command applied for this job.
%        This command can use the variables FILES_IN, FILES_OUT, FILES_CLEAN 
%        and OPT associated with the job (see below).
%        Examples :
%         'niak_brick_something(files_in,files_out,opt);'
%         'my_function(opt)'
%
%    FILES_IN
%        (string, cell of strings, structure whose terminal nodes are
%        string or cell of strings)
%        The files used as input by the command. Note that for properly
%        handling dependencies, this field needs to contain the exact
%        name of the file (full path, no wildcards, no '' for default
%        values).
%
%    FILES_OUT
%        (string, cell of strings, structure whose terminal nodes are
%        string or cell of strings) The list of files generated by the 
%        command. Note that for properly handling dependencies, this
%        field needs to contain the exact name of the file
%        (full path, no wildcards, no '' for default values).
%
%    FILES_CLEAN
%        (string, cell of strings, structure whose terminal nodes are
%        string or cell of strings) The list of files deleted by the
%        command. Note that for properly handling dependencies, this
%        field needs to contain the exact name of the file
%        (full path, no wildcards, no '' for default values).
%
%    DEP 
%        (cell of strings) a list of job names. The job <JOB_NAME> 
%        will have a dependency set on these jobs.
%
%    OPT
%        (any matlab variable) options of the job. This field has no
%        impact on dependencies. OPT can for example be a structure,
%        where each field will be used as an argument of the command.
%        The options will be scanned to check if a job has changed, 
%        should a pipeline be executed multiple times using the same
%        logs folder.
%
% OPT
%    (structure) with the following fields :
%
%    PATH_LOGS
%        (string) The folder where the "memory" of the pipeline 
%        manager will be stored. See the COMMENTS section below.
%
%    MODE
%        (string, default GB_PSOM_MODE defined in PSOM_GB_VARS)
%        how to execute the jobs :
%        'session'    : same as 'background', with MAX_QUEUED=1.
%        'background' : background execution, not-unlogin-proofed 
%                       (asynchronous system call).
%        'batch'      : background execution, unlogin-proofed ('at' in 
%                       UNIX, start in WINDOWS).
%        'qsub'       : remote execution using qsub (torque, SGE, PBS).
%        'msub'       : remote execution using msub (MOAB)
%        'bsub'       : remote execution using bsub (IBM)
%        'condor'     : remote execution using condor
%
%    MODE_PIPELINE_MANAGER
%        (string, default GB_PSOM_MODE_PM defined in PSOM_GB_VARS)
%        same as OPT.MODE, but applies to the pipeline manager itself.
%
%    MAX_QUEUED
%        (integer, default GB_PSOM_MAX_QUEUED defined in PSOM_GB_VARS)
%        The maximum number of jobs that can be processed
%        simultaneously. Some qsub systems actually put restrictions
%        on that. Contact your local system administrator for more info.
%
%    MAX_BUFFER
%        (integer, default 2)
% 
%    NB_RESUB
%        (integer, default 0 in 'session', opt.max_queued otherwise) 
%        The number of times a worker will be resubmitted if it fails.
%
%    SHELL_OPTIONS
%        (string, default GB_PSOM_SHELL_OPTIONS defined in PSOM_GB_VARS)
%        some commands that will be added at the begining of the shell
%        script submitted to batch or qsub. This can be used to set
%        important variables, or source an initialization script.
%
%    QSUB_OPTIONS
%        (string, GB_PSOM_QSUB_OPTIONS defined in PSOM_GB_VARS)
%        This field can be used to pass any argument when submitting a
%        job with bsub/msub/qsub. For example, '-q all.q@yeatman,all.q@zeus' will
%        force qsub to only use the yeatman and zeus workstations in the
%        all.q queue. It can also be used to put restrictions on the
%        minimum avalaible memory, etc.
%
%    FLAG_SHORT_JOB_NAMES
%        (boolean, default true) only the 8 first characters of a job 
%        name are used to submit to qsub/msub. Most qsub systems truncate
%        the name of the job anyway, and some systems even refuse to
%        submit jobs with long names.
%
%    COMMAND_MATLAB
%        (string, default GB_PSOM_COMMAND_MATLAB or
%        GB_PSOM_COMMAND_OCTAVE depending on the current environment,
%        defined in PSOM_GB_VARS)
%        how to invoke matlab (or OCTAVE).
%        You may want to update that to add the full path of the command.
%        The defaut for this field can be set using the variable
%        GB_PSOM_COMMAND_MATLAB/OCTAVE in the file PSOM_GB_VARS.
%
%    INIT_MATLAB
%        (string, GB_PSOM_INIT_MATLAB defined in PSOM_GB_VARS) a matlab 
%        command (multiple commands can actually be passed using comma 
%        separation) that will be executed at the begining of any 
%        matlab/Octave job.
%
%    PATH_SEARCH
%        (string, default GB_PSOM_PATH_SEARCH in the file PSOM_GB_VARS). 
%        If PATH_SEARCH is empty, the current path is used. If 
%        PATH_SEARCH equals 'gb_psom_omitted', then PSOM will not attempt 
%        to set the search path, i.e. the search path for every job will 
%        be the current search path in 'session' mode, and the default 
%        Octave/Matlab search path in the other modes. 
%
%    RESTART
%        (cell of strings, default {}) any job whose name contains one
%        of the strings in RESTART will be restarted
%
%    TYPE_RESTART
%        (string, default 'substring') defines how OPT.RESTART is to be
%        interpreted. Available options:
%        'substring' : restart jobs whose name contains one of the 
%            string in OPT.RESTART
%        'exact' restart jobs whose name is listed in OPT.RESTART.
%
%    FLAG_PAUSE
%        (boolean, default false) If FLAG_PAUSE is true, the pipeline
%        initialization will pause before writting the logs.
%
%    FLAG_FAIL
%        (boolean, default false) if true, the pipeline will throw an error 
%        if any of the job fails. 
%
%    FLAG_VERBOSE
%        (integer 0, 1 or 2, default 1) No verbose (0), standard 
%        verbose (1), a lot of verbose, useful for setting up the configuration (2), 
%        way too much verbose, only for debugging (3).
%
%    There are actually other minor options available, see
%    PSOM_PIPELINE_INIT and PSOM_PIPELINE_PROCESS for details.
%
% _________________________________________________________________________
% OUTPUTS:
%
% STATUS (integer) if the pipeline manager runs in 'session' mode, STATUS is 
% 0 if all jobs have been successfully completed, 1 if there were errors.
% In all other modes, STATUS is NaN.
%
% _________________________________________________________________________
% THE LOGS FOLDER:
%
% The pipeline manager is going to try to process the pipeline and create
% all the output files. In addition logs and parameters of the pipeline are
% stored in the log folder :
%
% PIPE.mat
%
%    A .MAT file with the following variables:
%
%    HISTORY
%        A string recapituling when and who created the pipeline, (and
%        on which machine).
%
%    LIST_JOBS, FILES_IN, FILES_OUT, GRAPH_DEPS
%        See PSOM_BUILD_DEPENDENCIES for more info.
%
% PIPE_history.txt
%
%    A text file with the history of the pipeline. Basically, it keeps
%    track of the time of submission, completion and failure of all jobs
%    of the pipeline. If the pipeline is executed multiple times with
%    the same log folders, the history file is keeping track of all
%    sessions.
%
% PIPE_jobs.mat
%
%    A .mat file which contains variables <NAME_JOB> where NAME_JOB is
%    the name of any job in the pipeline, and is equal to the field
%    PIPELINE.<NAME_JOB> for the lattest execution of this job in the
%    pipeline.
%
% PIPE_logs.mat
%
%    A .mat file which contains variables <NAME_JOB> where NAME_JOB is
%    the name of any job in the pipeline. The variable <NAME_JOB> is a
%    string which contains the log of the job. Jobs that have not been
%    processed yet have an empty log.
%
% PIPE_news_feed.csv
%
%    A comma-separated values (csv) file, with one line per job 
%    submission/completion/failure. This file is reset everytime the 
%    pipeline is started. Jobs that were already completed/failed before
%    anything is processed are listed as such. This file is useful to 
%    monitor the activity of the pipeline manager for third-party 
%    software.
%    
% PIPE_status.mat
%
%    A .mat file which contains variables <NAME_JOB> where NAME_JOB is
%    the name of any job in the pipeline. The variable <NAME_JOB> is a
%    string which describes the current status of the job (either
%    'submitted', 'running', 'finished', 'failed', 'none').
%
% PIPE_profile.mat
%
%    A .mat file which contains variables <NAME_JOB> where NAME_JOB is
%    the name of any job in the pipeline. The variable <NAME_JOB> is a
%    structure where each field is a profile variable fot the execution
%    of the job.
%
% _________________________________________________________________________
% SEE ALSO:
% PSOM_DEMO_PIPELINE, PSOM_CONFIG, PSOM_PIPELINE_VISU, 
% PSOM_PIPELINE_PROCESS, PSOM_PIPELINE_INIT
%
% _________________________________________________________________________
% COMMENTS:
%
% Empty file strings or strings equal to 'gb_niak_omitted' in the pipeline
% description are ignored in the dependency graph and checks for
% the existence of required files.
%
% If a pipeline is already running (a 'PIPE.lock' file could be found in
% the logs folder), a warning will be issued and the user may not restart
% the pipeline. To force a restart of the pipeline, the '.lock' file 
% has to be manually deleted before, which will force the pipeline manager
% to stop running if it is still active before the pipeline can be
%  restarted.
%
% If this is not the first time a pipeline is executed, the pipeline
% manager will check which jobs have been successfully completed, and will
% not restart these ones. If a job description has somehow been
% modified since a previous processing, this job and all its children will
% be restarted. For more details on this behavior, please read the
% documentation of PSOM_PIPELINE_INIT or run the pipeline demo in
% PSOM_DEMO_PIPELINE.
%
% Copyright (c) Pierre Bellec, Montreal Neurological Institute, 2008-2010.
% Departement d'informatique et de recherche operationnelle
% Centre de recherche de l'institut de Geriatrie de Montreal
% Universite de Montreal, 2011
% Maintainer : pierre.bellec@criugm.qc.ca
% See licensing information in the code.
% Keywords : pipeline

% Permission is hereby granted, free of charge, to any person obtaining a copy
% of this software and associated documentation files (the "Software"), to deal
% in the Software without restriction, including without limitation the rights
% to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
% copies of the Software, and to permit persons to whom the Software is
% furnished to do so, subject to the following conditions:
%
% The above copyright notice and this permission notice shall be included in
% all copies or substantial portions of the Software.
%
% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
% IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
% FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
% AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
% LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
% OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
% THE SOFTWARE.

psom_gb_vars

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Setting up default values for inputs %%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% SYNTAX
if ~exist('pipeline','var')||~exist('opt','var')
    error('SYNTAX: [] = PSOM_RUN_PIPELINE(FILE_PIPELINE,OPT). Type ''help psom_run_pipeline'' for more info.')
end

%% Constants
% Time to wait after the pipeline exited
wait_exit = 1;

%% Options
name_pipeline = 'PIPE';

opt = psom_struct_defaults( opt , ... 
   {'max_buffer' , 'flag_spawn' , 'flag_fail' , 'flag_short_job_names' , 'nb_resub'       , 'type_restart' , 'flag_pause' , 'init_matlab'       , 'flag_update' , 'path_search'       , 'restart' , 'shell_options'       , 'path_logs' , 'command_matlab' , 'flag_verbose' , 'mode'       , 'mode_pipeline_manager' , 'max_queued'       , 'qsub_options'       , 'time_between_checks' , 'nb_checks_per_point' , 'time_cool_down' }, ...
   {2            , false        , false       , true                   , gb_psom_nb_resub , 'substring'    , false        , gb_psom_init_matlab , true          , gb_psom_path_search , {}        , gb_psom_shell_options , NaN         , ''               , 1              , gb_psom_mode , gb_psom_mode_pm         , gb_psom_max_queued , gb_psom_qsub_options , []                    , []                    , []               });

opt.flag_debug = opt.flag_verbose>1;

if ~strcmp(opt.path_logs(end),filesep)
    opt.path_logs = [opt.path_logs filesep];
end
psom_mkdir(opt.path_logs);

if isempty(opt.path_search)
    opt.path_search = path;
end

if isempty(opt.command_matlab)
    if strcmp(gb_psom_language,'matlab')
        opt.command_matlab = gb_psom_command_matlab;
    else
        opt.command_matlab = gb_psom_command_octave;
    end
end

if strcmp(opt.mode,'session')
    opt.max_queued = 1;
    max_queued = 1;
    opt.mode = 'background';
end

if opt.max_queued == 0
    switch opt.mode
        case {'batch','background'}
            if isempty(gb_psom_max_queued)
                opt.max_queued = 1;
            else
                opt.max_queued = gb_psom_max_queued;
            end
        case {'session','qsub','msub','condor','bsub'}
            if isempty(gb_psom_max_queued)
                opt.max_queued = Inf;
            else
                opt.max_queued = gb_psom_max_queued;
            end
    end % switch action
end % default of max_queued

% Limit the number of workers based on the number of jobs in the pipeline
opt.max_queued = min(opt.max_queued,length(fieldnames(pipeline)));

if ~ismember(opt.mode,{'session','background','batch','qsub','msub','bsub','condor'})
    error('%s is an unknown mode of pipeline execution. Sorry dude, I must quit ...',opt.mode);
end

switch opt.mode
    case 'session'
        if isempty(opt.time_between_checks)
            opt.time_between_checks = 0;
        end
        if isempty(opt.nb_checks_per_point)
            opt.nb_checks_per_point = Inf;
        end
        if isempty(opt.nb_resub)
            opt.nb_resub = 0;
        end
    otherwise
        if isempty(opt.time_between_checks)
            opt.time_between_checks = 0.5;
        end
        if isempty(opt.nb_checks_per_point)
            opt.nb_checks_per_point = 60;
        end
        if isempty(opt.nb_resub)
            opt.nb_resub = opt.max_queued;
        end
end

if opt.flag_verbose == 2
    fprintf('PSOM deamon is running in mode: ''%s''\n',opt.mode_pipeline_manager);
    fprintf('Jobs are running in mode: ''%s''\n',opt.mode_pipeline_manager);
    fprintf('Number of workers: %i\n',opt.max_queued);
    fprintf('Max number of buffered jobs: %i\n',opt.max_buffer)
    fprintf('Number of resubmissions: %i\n',opt.nb_resub)
    fprintf('Options for qsub: %s\n',opt.qsub_options)
    fprintf('Options for the shell: %s\n',opt.shell_options)
    fprintf('Command to start matlab/octave: %s\n',opt.command_matlab)
    fprintf('Search path for matlab/octave: %s (...)\n',opt.path_search(1:200))
    fprintf('Time between checks: %1.1f\n',opt.time_between_checks)
    fprintf('Number of checks per point: %i\n',opt.nb_checks_per_point)
end
    
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% The pipeline processing starts now  %%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% file names
file_pipe_running = cat(2,opt.path_logs,filesep,name_pipeline,'.lock');
file_logs = cat(2,opt.path_logs,filesep,name_pipeline,'_history.txt');
file_status = cat(2,opt.path_logs,filesep,name_pipeline,'_status.mat');

%% Check for a 'lock' tag
if exist(file_pipe_running,'file') % Is the pipeline running ?

    fprintf('\nA lock file %s has been found on the pipeline !\nIf the pipeline crashed, press CTRL-C now, delete manually the lock and restart the pipeline.\nOtherwise press any key to monitor the current pipeline execution.\n\n',file_pipe_running)
    pause
    psom_pipeline_visu(opt.path_logs,'monitor');
    return
end

%% Initialize the logs folder
opt_init.path_logs      = opt.path_logs;
opt_init.path_search    = opt.path_search;
opt_init.command_matlab = opt.command_matlab;
opt_init.flag_verbose   = opt.flag_verbose;
opt_init.restart        = opt.restart;
opt_init.flag_update    = opt.flag_update;    
opt_init.flag_pause     = opt.flag_pause;
opt_init.type_restart   = opt.type_restart;

[tmp,flag_start] = psom_pipeline_init(pipeline,opt_init);   
if ~flag_start
    return
end

%% Save the configuration
file_config = [opt.path_logs 'PIPE_config.mat'];
save(file_config,'-struct','opt')
    
%% Run the pipeline manager
file_pipeline = cat(2,opt.path_logs,filesep,name_pipeline,'.mat');

%% Create a folder for the PSOM deamon
path_deamon = [opt.path_logs 'deamon' filesep];
if psom_exist(path_deamon)
    psom_clean(path_deamon,struct('flag_verbose',false));
end
psom_mkdir(path_deamon);

%% Create a folder for the garbage collector 
path_garbage = [opt.path_logs 'garbage' filesep];
if psom_exist(path_garbage)
    psom_clean(path_garbage,struct('flag_verbose',false));
end
psom_mkdir(path_garbage);

%% The options for the deamon
if strcmp(opt.mode,'session')
    opt_d.heartbeat = true;
    opt_d.spawn = false;
else
    opt_d.mode           = opt.mode;
    opt_d.mode_pipeline_manager = opt.mode_pipeline_manager;
    opt_d.max_queued     = opt.max_queued;
    opt_d.max_buffer     = opt.max_buffer;
    opt_d.nb_resub       = opt.nb_resub;
    opt_d.shell_options  = opt.shell_options;
    opt_d.qsub_options   = opt.qsub_options;
    opt_d.command_matlab = opt.command_matlab;
    opt_d.init_matlab    = opt.init_matlab;
    opt_d.flag_verbose   = opt.flag_verbose;
    opt_d.time_between_checks = opt.time_between_checks;
    opt_d.nb_checks_per_point = opt.nb_checks_per_point;
end
file_opt_deamon = [path_deamon 'opt_deamon.mat'];
save(file_opt_deamon,'-struct','opt_d');
    
%% Options to submit scripts
opt_script.path_search    = [opt.path_logs 'PIPE.mat'];
opt_script.mode           = opt.mode_pipeline_manager;
opt_script.init_matlab    = opt.init_matlab;
opt_script.flag_debug     = opt.flag_verbose == 2;        
opt_script.shell_options  = opt.shell_options;
opt_script.command_matlab = opt.command_matlab;
opt_script.qsub_options   = opt.qsub_options;
opt_script.name_job       = 'psom_deamon';   
    
%% Options for submission of the pipeline manager
if strcmp(opt.mode,'session')
    opt_logs.txt = file_logs;
else
    opt_logs.txt = [path_deamon 'deamon.log'];
end
opt_logs.eqsub  = [path_deamon 'deamon.eqsub'];
opt_logs.oqsub  = [path_deamon 'deamon.oqsub'];
opt_logs.failed = [path_deamon 'deamon.failed'];
opt_logs.exit   = [path_deamon 'deamon.exit'];
if strcmp(opt.mode,'session') 
    cmd_deamon = sprintf('flag = load(''%s''); psom_worker(''%s'',flag);',file_opt_deamon,opt.path_logs);    
else
    cmd_deamon = sprintf('opt = load(''%s''); psom_deamon(''%s'',opt);',file_opt_deamon,opt.path_logs);    
end

if ispc % this is windows
    script_deamon = [path_deamon filesep 'psom_deamon.bat'];
else
    script_deamon = [path_deamon filesep 'psom_deamon.sh'];
end
[flag_failed,msg] = psom_run_script(cmd_deamon,script_deamon,opt_script,opt_logs,opt.flag_verbose);

%% If not in session mode, monitor the output of the pipeline
flag_exit = false;
if opt.flag_verbose&&~strcmp(opt.mode_pipeline_manager,'session')
    nb_chars = 0;
    nb_chars_old = 0;
    while (nb_chars==0)||~flag_exit
        flag_exit = ~psom_exist(file_pipe_running);
        nb_chars_old = nb_chars;
        nb_chars = psom_pipeline_visu(opt.path_logs,'monitor',nb_chars);
        if nb_chars == nb_chars_old        
            if exist('OCTAVE_VERSION','builtin')  
                [res,msg] = system('sleep 0.2');
            else
                sleep(0.2); 
            end
        end
    end
end

%% check the status of the pipeline
status = load(file_status);
status = struct2cell(status);
status = any(strcmp(status,'failed'));