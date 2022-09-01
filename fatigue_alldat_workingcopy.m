%% FATIGUE v7

%% setup
run_script = 1;
%rootDir    = '/Volumes/smb fatigue'; % mac root
%rootDir = '\\JOSHUAS-MACBOOK\smb fatigue\database'; % windows root network
%rootDir = 'F:\database'; %windows root hd over usb
%rootDir = '\\jmg\home\Drive\fatigue\database'; %windows root nas
rootDir = 'D:\Joshua\fatigue\database'; %windows root internal hd

%% print legend to cml

%display available operations
operations_list = ...
    "––––––––––––––––––––––––––––––––––––––––––––––––––––\n"+...
    "Available operations:\n"+...
    "\n"+...
    "setup\n"+...
    "11  set root directory\n"+...
    "12  load data\n"+...
    "13  create fatigue_alldat\n"+...
    "\n"+...
    "processing\n"+...
    "21  mark outliers\n"+...
    "22  process inlcuded raw data\n"+...
    "23  standardize length/time\n"+...
    %"24  leads as columns\n"+...
    "25  calculate mean trial\n"+...
    "26  calculate variables\n"+...
    "\n"+...
    "output\n"+...
    "51  save alldat\n"+...
    "\n"+...
    "\n"+...
    "clear cml & display operations with 0\n"+...
    "terminate script with 666\n"+...
    "clear workspace with 911\n";

fprintf(operations_list);

%% master while loop
while run_script == 1
    
%Select Operation
disp(' ')
disp('––––––––––––––––––––––––––––––––––––––––––––––––––––')
action = input('What would you like me to do? ');
disp(' ')

switch action

    %% 
    case 11 % set root directory
        %%
        rootDir = input('root directory: ','s');
        disp(' ')
        disp("  root directory set to '"+rootDir+"'")
        %% end Case 11: Set root directory

    case 12 % load data
        %%
        disp('1 alldat (w/wo emg data)')
        disp('2 parameters')
        disp('3 missing trials list')
        disp(' ')
        what_to_load = input('what to load: ');

        switch what_to_load
            case 1 %load alldat
                [f,p] = uigetfile(fullfile(rootDir,'*.mat'),'Select the fatigue_alldat');

                time_start = now;
                fatigue_alldat = load(fullfile(p,f));
                fatigue_alldat = fatigue_alldat.fatigue_alldat;

                disp('  -> fatigue_alldat loaded')
                disp(strcat("     runtime ", datestr(now - time_start,'HH:MM:SS')))

            case 2 %load parameters
                [f,p] = uigetfile(fullfile(rootDir,'*.*'),'Select the Fatigue Parameter File (.tsv)');
                Parameters = dload(fullfile(p,f));
                disp('  -> Parameters loaded')

            case 3
                [f,p] = uigetfile(fullfile(rootDir,'*.*'),'Select the Missing Trials List (.tsv)');
                Missing_Trials = dload(fullfile(p,f));

                missing_trials = [];

                for i = 1:length(Missing_Trials.ID)
                    trial = [char(Missing_Trials.ID(i)),'.',num2str(Missing_Trials.day(i)),'.',char(Missing_Trials.BN(i)),'.',char(Missing_Trials.trial(i))];
                    missing_trials = [missing_trials; string(trial)];
                end
                disp('  -> Missing Trials loaded')
        end
        %% end Case 12: load data


    case 13 % create fatigue_alldat        
        %%
        [p] = uigetdir(rootDir,'Select the EMG Cut Trials folder');

        %Setup Progress bar
        counter = 0;
        h = waitbar(0,'Processing Cut Trial EMG Data 0%');
        total = length(Parameters.SessN)*30*5;

        %Create allDat of Procesed Cut Trial EMG Data based on Parameters File
        fatigue_alldat = [];
        leads = {'adm' 'apb' 'fdi' 'bic' 'fcr'};
        LEADS = {'ADM' 'APB' 'FDI' 'BIC' 'FCR'};

        time_start = now;
        %create alldat
        for i = 1:length(Parameters.SessN)

            id = Parameters.ID(i);
            day = Parameters.day(i);
            block = Parameters.BN(i);

            %Check for missing day or block and skip if true
            test_str1 = char(strcat(id,'.',num2str(day),'.all.all'));
            test_str2 = char(strcat(id,'.',num2str(day),'.',num2str(block),'.all'));
            if sum(contains(missing_trials,test_str1))>0
                continue
            end
            if sum(contains(missing_trials,test_str2))>0
                continue
            end

            folder = strcat(id,'_EMGAnalysis_d',num2str(day));

            for j = 1:30

                % check for missing trial and skip if true
                test_str3 = char(strcat(id,'.',num2str(day),'.',num2str(block),'.',num2str(j)));
                if sum(contains(missing_trials,test_str3))>0
                    continue
                end

                for k = 1:5
                    new_line = [];
                    
                    l = leads(k);
                    l = l{1,1};
                    L = LEADS(k);
                    L = L{1,1};

                    %Load the Trial File
                    file = strcat(id,'_EMG_d',num2str(day),'_b',num2str(block),'_t',num2str(j),'.txt');
                    D = dload(char(fullfile(p,folder,file)));

                    %Add EMG
                    new_line.raw = D.(L);

                    %Add Parameters
                    new_line.type = "trial";
                    new_line.lead = string(l);
                    new_line.exclude = "";
                    new_line.trial_number = j;

                    parameter_fields = fields(Parameters);
                    for m = 1:length(parameter_fields)
                        new_line.(char(parameter_fields(m))) = Parameters.(char(parameter_fields(m)))(i);
                    end

                    %Add Processed Trial to allDat 'EMG_clean'
                    fatigue_alldat = [fatigue_alldat new_line];
                    
                    %Update Progress bar
                    counter = counter+1;
                    waitbar(counter/total,h,['Processing Cut Trial EMG Data ', num2str(round(counter/total*100)),'%']);
                end

            end

        end %End of Paramtere Iteration
        
        fatigue_alldat = table2struct(struct2table(fatigue_alldat),'ToScalar',true);
        
        close(h);
        disp("  -> fatigue_alldat created")
        disp(strcat("     runtime: ", datestr(now - time_start,'HH:MM:SS')))
        %% end case 13 create alldat

    case 21 % update inclusion status
        %%
        [f,p] = uigetfile(fullfile(rootDir,"*.csv"),"Select the status update file","status_update.csv");
        status_update = table2struct(readtable(fullfile(p,f)),'ToScalar',true);
        
        start_time = now;
        for i = 1:length(fatigue_alldat.SubjN)
            a = string(status_update.status(...
                        status_update.subjn == fatigue_alldat.SubjN(i)&...
                        status_update.day   == fatigue_alldat.day(i)&...
                        status_update.BN    == fatigue_alldat.BN(i)&...
                        (status_update.trial_number == fatigue_alldat.trial_number(i) | isnan(status_update.trial_number))  &...
                        status_update.lead  == fatigue_alldat.lead(i)...
                        ));
            if isempty(a)
                fatigue_alldat.exclude(i) = "FALSE";
            else
                fatigue_alldat.exclude(i) = a;
            end
        end
        disp("  -> Status updated")
        disp(" ")
        disp(strcat("     Total Trials excluded: ",num2str(sum(fatigue_alldat.exclude == "TRUE"))))
        disp("     compare total to excel to double check correct update ")
        %% end case 21 update inclusion status

    case 22 % process included raw data
        SRATE = 5000;
        freq_h = 10;
        freq_l = 6;
        ORDER = 4;
        
        %Setup Progress bar
        counter = 0;
        h = waitbar(0,['Processing Raw Data ', num2str(counter*100),'%']);
        total = length(fatigue_alldat.SubjN);

        start_time = now;
        for i = 1:length(fatigue_alldat.SubjN)

            if fatigue_alldat.exclude(i) == "TRUE"
                fatigue_alldat.proc(i,1) = {{}};
            else
                a = fatigue_alldat.raw(i);
                fatigue_alldat.proc(i,1) = {proc_std(a{1,1}, SRATE, freq_h, freq_l, ORDER)};
            end
            
            %Update Progress bar
            counter = counter+1;
            waitbar(counter/total,h,['Processing Raw Data ', num2str(round(counter/total*100)),'%']);
        end
        disp("  -> Raw Data processed")
        disp(strcat("     runtime: ",datestr(now-start_time,"MM:SS")))
        close(h)
        %% end case 22 process raw data
        
    case 23 % standardize length/time
        %%
        LENGTH = 100000;
        
        %Setup Progress bar
        counter = 0;
        h = waitbar(0,['Standardising for Time ', num2str(counter*100),'%']);
        total = length(fatigue_alldat.SubjN);

        start_time = now;
        for i = 1:length(fatigue_alldat.SubjN)

            if fatigue_alldat.exclude(i) == "TRUE"
                fatigue_alldat.stnd(i,1) = {{}};
            else
                a = fatigue_alldat.proc(i);
                fatigue_alldat.stnd(i,1) = {stnd4time(a{1,1}, LENGTH)};
            end
            
            %Update Progress bar
            counter = counter+1;
            waitbar(counter/total,h,['Standardising for Time ', num2str(round(counter/total*100)),'%']);
        end
        disp("  -> Trials standardized for Time")
        disp(strcat("     runtime: ",datestr(now-start_time,"MM:SS")))
        close(h)
        %% end case 23 standardize length/time

    case 24 % create standardized emg table
        %%

        stnd_emg_table = array2table(zeros(length(fatigue_alldat.label),7));
        stnd_emg_table.Properties.VariableNames = {'group' 'subject' 'day' 'session' 'trial' 'lead' 'processed'};

        stnd_emg_table.group   = fatigue_alldat.label;
        stnd_emg_table.subject = fatigue_alldat.SubjN;
        stnd_emg_table.day     = fatigue_alldat.day;
        stnd_emg_table.session = fatigue_alldat.BN;
        stnd_emg_table.trial   = fatigue_alldat.trial_number;
        stnd_emg_table.lead    = fatigue_alldat.lead;
        stnd_emg_table.emg     = fatigue_alldat.stnd;

        fatigue_alldat.processed = stnd_emg_table;
        fatigue_alldat.processed = unstack(fatigue_alldat.processed,'processed', 'lead');
        %% end case 24 leads as columns

    case 25 % calculate mean trial
        %%
        mean_trials = [];
        
        blocks = unique([fatigue_alldat.SubjN fatigue_alldat.day fatigue_alldat.BN fatigue_alldat.lead],'rows');
        blocks = table2struct(cell2table([num2cell(arrayfun(@str2num,blocks(:,1:3))) num2cell(blocks(:,4))],'VariableNames',["subjn" "day" "BN" "lead"]),'ToScalar',true);
        
        %Create empty stuct
        for i = 1:length(blocks.subjn)

            leads = {'adm' 'apb' 'fdi' 'bic' 'fcr'};
            
            new_line = [];
            new_line.subjn  = blocks.subjn(i);
            new_line.day    = blocks.day(i);
            new_line.BN     = blocks.BN(i);
            new_line.lead   = blocks.lead(i);
            
            mean_trials = [mean_trials new_line];

        end
        mean_trials = table2struct(struct2table(mean_trials),'ToScalar',true);
            
        %Fill struct with means
        counter = 0;
        h = waitbar(0,'Calculating mean Trial per Block 0%');
        total = length(blocks.subjn);

        start_time = now;
        for i = 1:length(blocks.subjn)
            
            a = fatigue_alldat.stnd(fatigue_alldat.SubjN  == blocks.subjn(i) &...
                                    fatigue_alldat.day    == blocks.day(i) &...
                                    fatigue_alldat.BN     == blocks.BN(i) &...
                                    fatigue_alldat.lead   == blocks.lead(i) &...
                                    fatigue_alldat.exclude ~= "TRUE" ...
                                    );
                                
            a = a(~cellfun(@isempty,a));
            b = length(a);
            a = cellfun(@transpose,a,'UniformOutput',false);
            a = cell2mat(a);
            a = sum(a);
            a = {transpose(a/b)};

            mean_trials.mean(i,1) = a;
            
            %Update Progress bar
            counter = counter+1;
            waitbar(counter/total,h,['Calculating mean Trial per Block ', num2str(round(counter/total*100)),'%']);
        end
        disp("  -> MeanTrials calculated")
        disp(strcat("     runtime: ",datestr(now-start_time,"MM:SS")))
        close(h)
        
        %% end case 25 create mean trial table
        
    case 26 % calculate distances
        %%
        start_time = now;
        stnd_emg_table = fatigue_alldat.processed;
        mean_trials = fatigue_alldat.mean_trials;

        % create table with header columns
        calc_variables = stnd_emg_table(:,1:5);
        
        % distances to calculate
        distances_to_calc = [...
            "adm";...
            "fdi";...
            "apb";...
            "fcr";...
            "bic";...
            ["fdi" "apb"];...
            ["fdi" "apb" "adm"];...
            ["fcr" "bic"];...
            ["fdi" "apb" "adm" "fcr" "bic"]...
            ];

        % calculate
        for i=1:length(distances_to_calc)
            request = distances_to_calc(i);

            %for every row…
            %   • get mean trial matrix
            %   • get trial matrix
            for j=i:length(request)
                
            end

            %   • Lpqnorm(1,2,trial - mean)
        end

        %Add empty var columns
        vars    = {'dist' 'max' 'dist2zero' 'corr'};
        l       = length(fatigue_alldat.SubjN);
        for i = vars
            fatigue_alldat.(i{1,1}) = zeros(l,1);
        end
        
        

        
        for i = 1:length(fatigue_alldat.SubjN)
                
            if fatigue_alldat.exclude(i) == "TRUE"
                %dist
                fatigue_alldat.dist(i) = nan;

                %max
                fatigue_alldat.max(i) = nan;

                %dist2zero
                fatigue_alldat.dist2zero(i) = nan;

                %correlation
                fatigue_alldat.corr(i) = nan;
            else
                %get trial_mean
                trial_mean = mean_trials.mean(mean_trials.subjn  == fatigue_alldat.SubjN(i) &...
                                              mean_trials.day    == fatigue_alldat.day(i) &...
                                              mean_trials.BN     == fatigue_alldat.BN(i) &...
                                              mean_trials.lead   == fatigue_alldat.lead(i)...
                                              );
                trial_mean = trial_mean{1};

                trial = fatigue_alldat.stnd(i);
                trial = trial{1,1};

                %dist
                a = dist([trial, trial_mean]);
                fatigue_alldat.dist(i) = a(1,2);

                %max
                fatigue_alldat.max(i) = max(trial);

                %dist2zero
                a = dist([trial, zeros(100000,1)]);
                fatigue_alldat.dist2zero(i) = a(1,2);

                %correlation
                a = corr([trial, trial_mean]);
                fatigue_alldat.corr(i) = a(1,2);
            end
            
            %Update Progress bar
            counter = counter+1;
            waitbar(counter/total,h,['Calculating Variables ', num2str(round(counter/total*100)),'%']);
        end
        
        disp("  -> Variables calculated")
        disp(strcat("     runtime: ",datestr(now-start_time,"MM:SS")))
        %% end case 25 calculate distances

    case 51 % save alldat
        %%
        [file, path] = uiputfile(fullfile(rootDir,'*.mat'));

        time_start = now;
        save(fullfile(path,file),'-struct','fatigue_alldat','-v7.3');

        disp('  -> fatigue_alldat saved')
        disp(strcat("     runtime ", datestr(now - time_start,'HH:MM:SS')))
        %% end case 51 save alldat
    case 0 % reset cml view
        %%
        clc
        fprintf(operations_list);
        %% end of case 0
    
    case 666 %%Case 666: Terminate Script   
        run_script = 0;
        
    case 911 %Case 911: Clear Workspace        

end % end of master switch
end % end of master while loop