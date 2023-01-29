%% FATIGUE v7 - further findings

%% setup
run_script = 1;

% set root directory
%rootDir    = '/Volumes/smb fatigue'; % mac root
%rootDir = '\\JOSHUAS-MACBOOK\smb fatigue\database'; % windows root network
%rootDir = 'F:\database'; %windows root hd over usb
%rootDir = '\\jmg\home\Drive\fatigue\database'; %windows root nas
rootDir = 'D:\Joshua\fatigue\database'; %windows root internal hd

% supress warnings

%% print legend to cml

%display available operations
operations_list = ... "––––––––––––––––––––––––––––––––––––––––––––––––––––\n"+...
"<strong>Available operations:</strong>\n"+...
"\n"+...
"setup\n"+...
"11  set root directory\n"+...
"12  load data\n"+...
"\n"+...
"correlation\n"+...
"21  create descriptive table\n"+...
"22  combine describtion and change tables\n"+...
"23  correlation loop\n"+...
"24  subtables by group & day\n"+...
"25  manual ttest loop\n"+...
"26  compare spaces manualy\n"+...
"27  compare spaces automaticaly\n"+...
"28  comparative model for subspaces"+...
"\n"+...
"30  view model"+...
"\n"+...
"\n"+...
"clear cml & display operations with 0\n"+...
"terminate script with 666\n"+...
"clear workspace with 911\n";

fprintf(operations_list);

%% master while loop
while run_script == 1
%% Select Operation
disp(' ')
disp('––––––––––––––––––––––––––––––––––––––––––––––––––––')
action = input('What would you like me to do? ');
disp(' ')
%%

switch action
    %% 
    case 11 % set root directory
        %%
        rootDir = uigetdir('','fatigue root directory');
        disp(' ')
        disp("  root directory set to '"+rootDir+"'")
        %% end Case 11: Set root directory

    case 12 % load data
        %%
        disp('1 alldat (w/wo emg data)')
        disp('2 parameters')
        disp('3 missing trials list')
        disp('4 load calc_variables')
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

            case 4
                [f,p] = uigetfile(fullfile(rootDir,'*.*'),'Select calc_variables (.csv)');
                calc_variables = readtable(fullfile(p,f));
                % calc_variables.Properties.VariableNames = ["group" "subject" "day" "session" "trial" "time" transpose(cellfun(@strjoin, distances_to_calc))];

        end
        %% end Case 12: load data


    
    case 21 % create descriptive table
        %% 

        % set_to_describe = table( var 1, var 2, var 3)
        % action(set_to_describe) = action_results_vector( 1, var 1 var 2 var 3 )
        % results_matrix transpose( [action_results_vector_1 ; action_results_vector_2 ; action_results_vector_1 ; …] )
        %
        % on sublevel: table( group, subject, time, var x action 1, action 2, action 3 )

        % possible input: 
        %       • subject, group or collective
        %       • timescale (trial, subsession, session, subday, day, two-day)
        %       • emg_space
        %   => ask for "inlcude" and "by"

        %% input
        include = [];
        by = [];

        emg_space = emgSpaceSelector(calc_variables);

        disp('inlcude:')
        include_group   = eval(input(' group: ','s'));
        % include_subject = input (' subject: ','s');
        include_days    = eval(input(' day: ','s'));
        include_session = eval(input(' session: ','s'));
        include_trial   = eval(input(' trial: ','s'));
        cutoff = input(' cutoff: ');

        disp('by:')
        by_time = input(' time: ','s');
        by_level = input(' level: ','s');

        
        %% get calcvar subset based on input emg_space and include
        calcvar_subset = [];

        for i = 1:length(include_group)
            group = include_group(i);
            calcvar_subset = [calcvar_subset; calc_variables(calc_variables.group == group, ["group", "subject", "day", "session", "trial", emg_space])];
        end

        if length(include_days) == 1
            calcvar_subset = calcvar_subset(calcvar_subset.day == include_days(1), :);
        end

        if length(include_session) < 4
            foo = calcvar_subset;
            calcvar_subset = [];
            for i = 1:length(include_session)
                session = include_session(i);
                calcvar_subset = [calcvar_subset; foo(foo.session == session, :)];
            end
            clearvars foo
        end

        if length(include_trial) < 30
            foo = calcvar_subset;
            calcvar_subset = [];
            for i = 1:length(include_trial)
                trial = include_trial(i);
                calcvar_subset = [calcvar_subset; foo(foo.trial == trial, :)];
            end
            clearvars foo
        end

        if cutoff < 100
            calcvar_subset = calcvar_subset(eval("calcvar_subset." + emg_space) < prctile(eval("calcvar_subset." + emg_space), cutoff), :);
        end

        

        %% calculate descriptives
        % description = {};
        operations = ["median", "mean", "max", "min"]; % ["length", "median", "mean", "mode", "range", "max", "min", "var", "std"]

        % create pivot rows command
        row_cmd = "["; % [calcvar_subset.group calcvar_subset.day]
        table_headings = [];

        if by_level == "group" || by_level == "subject"
            row_cmd = row_cmd + "calcvar_subset." + by_level + " ";
            table_headings = [table_headings string(by_level)];
        end

        if by_time == "day" || by_time == "session"
            row_cmd = row_cmd + "calcvar_subset." + by_time + "]";
            table_headings = [table_headings string(by_time)];
        end

        for i = 1
            operation = operations(i);
            [FA,RA,CA] = pivottable(eval(row_cmd), [], eval('calcvar_subset.'+string(emg_space)), operation);
        end

        table_headings = [table_headings, operations];
        description = array2table(zeros(height(FA),length(table_headings)));
        description.Properties.VariableNames = table_headings;
        description{:,1:width(RA)} = RA;
        description{:,operation} = FA;

        for i = 2:length(operations)
            operation = operations(i);
            [FA,RA,CA] = pivottable(eval(row_cmd), [], eval('calcvar_subset.'+string(emg_space)), operation);
            description{:,operation} = FA; % description = {description; {operation transpose(FA)}};
        end

%         table_headings = [table_headings transpose(RA)];
%         description = [table_headings; description];
%         description = transpose(description);
%         description = array2table(description(2:height(description),:),'VariableNames',description(1,:));
%         disp(description);
        %%

    case 22 % combine description and change table
        fprintf("<strong>combine description and change table</strong>\n")
        %% calculate change table with slope and difference of variability and skill difference
        emg_space = emgSpaceSelector(calc_variables);
        parameters = struct2table(Parameters);
%         subject_list = unique(Parameters.SubjN);
        
        subject_list = [5	6	8	9   11	12	13	14	15	16	17	18	19	20	21	22	23	24	25	26	27	28	29	30	31	32	33	34	35	36	37	38	39	40	41	42	43	44];
            % manually excluded: 10, 45
        change_table = array2table(zeros(80, 6));
        change_table.Properties.VariableNames = {'subject', 'group', 'day', 'variability_slope', 'variability_difference', 'skill_difference'};


        for i = 1:length(subject_list)
            subject = subject_list(i);
            group = unique(parameters{parameters.SubjN == subject,"label"});
        
            skill       = Parameters.skillmeas(Parameters.SubjN == subject);
            variability = calc_variables(calc_variables.subject == subject, ["day", "session", "group", "time", emg_space]);
            
            variability_session_mean = [];
            for day = 1:2

                %% variability slope
                % get observed values from calc_variables_subset
                dependant = variability(variability.day == day, emg_space);
                dependant = table2array(dependant);
        
                % get regressors
                regressors = variability(variability.day == day, "time");
                regressors = table2array(regressors);

                % fit model
                if subject == 10 || 45
                    robust_on = 'off';
                else
                    robust_on = 'on';
                end

                mdlr = fitlm(regressors,dependant,'RobustOpts',robust_on);
                variability_slope = mdlr.Coefficients{2,1};

                %% variability difference
                variability_session_1 = median(variability{variability.day == day & variability.session == 1, emg_space});
                variability_session_4 = median(variability{variability.day == day & variability.session == 4, emg_space});
                variability_difference = variability_session_4 - variability_session_1;

                %% skill
                % get observed values from calc_variables_subset
                if day == 1
                    skill_difference = skill(4)-skill(1);
                else
                    skill_difference = skill(8)-skill(5);
                end

                %% add to change table
                change_table((i-1)*2+day, :) = array2table([subject, group, day, variability_slope, variability_difference, skill_difference]);

            end

        end

        %% combine change_table and descriptive

        to_add = ["variability_slope" "variability_difference" "skill_difference"];

        if by_level == "subject"
            to_add = [to_add "group"];
        end

        table_headings = [table_headings to_add];

        description = [description array2table(zeros(height(description),length(to_add)))];
        description.Properties.VariableNames = table_headings;

        
        for row = 1:height(description)
            for j = 1:length(to_add)
                var_to_add = to_add(j);
                insert = change_table{ ...
                                         change_table{:, "subject"} == description{row, "subject"} &...
                                         change_table{:, "day"} == description{row, "day"}, ...
                                         var_to_add...
                                      };
                
                if isempty(insert)
                    insert = nan(1);
                end

                description{row, var_to_add} = insert;
            end
        end

%         fprintf("<strong>descriptive table</strong>\n")
%         disp(description)

        %%

    case 23 % correlate
        fprintf("<strong>correlation loop</strong>\n")
        %%
        %input
        disp(' ')
        disp("available for correlation:")
        disp(table_headings)
        
        correlation_loop = true; 
        while correlation_loop
            disp(' ')
            disp("available correlation coefficients")
            disp(" p: Pearson   s: Spearman   k: Kendall")
            disp(' ')
            var1 = input('variable 1: ','s');

            if var1 == "quit"
                break
            end

            var2 = input('variable 2: ','s');
            corr_type = input('corr type:  ','s');
    
            switch corr_type
                case "p"
                    corr_type = "Pearson";
    
                case "s"
                    corr_type = "Spearman";
    
                case "k"
                    corr_type = "Kendall";
            end
    
            % correlate & scatter plot
            corr_table = array2table(zeros(6,4));
            corr_table.Properties.VariableNames = ["group" "day" "coefficient" "p"];
            figure();
            t = tiledlayout(2,3);
            title(t, "Scatter Plots: " + var1 + " and " + var2);
            for group = 1:3
                for day = 1:2
    
                    nexttile((day-1)*3+group)
                    hold on
    
                    scatter(description{change_table.day == day & change_table.group == group, var1}, description{change_table.day == day & change_table.group == group, var2})
                    
                    h = lsline;
    
                    title("group " + group + " day " + day)
                    xlabel(var1)
                    ylabel(var2)
                    
                    hold off
    
                    [r, p] = corr(description{change_table.day == day & change_table.group == group, var1}, description{change_table.day == day & change_table.group == group, var2},...
                                    'Type', corr_type,'rows','complete');
                    corr_table{(group-1)*2+day , :} = [group day r p];
                    
                end
            end
            drawnow()
            disp(' ')
            fprintf("<strong>" + corr_type + ": " + string(var1) + " x " + string(var2) + "</strong>\n")
            disp(corr_table);
        end

        %%

    case 24 % table by group
        fprintf("<strong>table by group</strong>\n")
        %%
        %input
        disp(' ')
        disp("available variables:")
        disp(table_headings)
        
        disp(' ')
        vars  = input('vars:  ');
        group = input('group: ');
        day   = input('day:   ');

        % get subtable
        fprintf("<strong> group " + group + "  day " + day + "</strong>\n")
        subtable = description(description.group == group & description.day == day, vars);
        disp(subtable)
        %%

    case 25 % manual ttest
        %%
        fprintf("<strong>ttest loop</strong>\n")

        ttest_loop = true;

        while ttest_loop
            disp(' ')
            disp('group 1')
            x1 = input(' - mean: ','s');

            if x1 == "quit"
                break
            else
                x1 = str2double(x1);
            end

            s1 = input(' - std:  ');
            n1 = input(' - n:    ');
            disp(' ')
            disp('group 2')
            x2 = input(' - mean: ');
            s2 = input(' - std:  ');
            n2 = input(' - n:    ');
            disp(' ')
            [t, p] =ttest_manual(x1, s1, n1, x2, s2, n2);
            disp("t: "+string(t)+"  p: "+string(p))

        end
        %%

    case 26 % compare spaces manualy
        %%
        fprintf("<strong>compare spaces manualy</strong>\n")
        group = input('group: ');
        day   = input('day:   ');

        spaces = [11 12 2 3 1]; %[9 7 8 6 2 3 1 4 5];

        for i = 1:length(spaces)
            %% input
            % emg space selector
            space_index = spaces(i);
            emg_spaces = calc_variables.Properties.VariableNames;
            emg_space = emg_spaces{space_index+6};
    
            % other input
            multiple_yn  = 'n'; %input('multiple: ','s');
            days_on_graph = 1; %input('days:     ');
    
            % get subset of calc_variables to be tested
            if days_on_graph == 1
                stencil = (calc_variables.group == group & calc_variables.day == day);
            else
                stencil = (calc_variables.group == group);
            end
    
            calc_variables_subset = calc_variables(stencil,:);
    
            % get observed values from calc_variables_subset
            dependant = calc_variables_subset(:, emg_space);
            dependant = table2array(dependant);
    
            % get regressors
            if multiple_yn == "n"
                regressors_names = "time";
            elseif days_on_graph == 2
                regressors_names = ["day" "session" "trial"];
            else
                regressors_names = ["session" "trial"];
            end
    
            regressors = calc_variables_subset(:, regressors_names);
            regressors_names = regressors.Properties.VariableNames;
            regressors = table2array(regressors);
            mdlr = fitlm(regressors,dependant,'RobustOpts','on');
    
            %%
            %output
            if days_on_graph == 2
                output_heading_days = " Both Days";
            else
                output_heading_days = " Day "+string(day);
            end
            
            disp(' ')
            disp("–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––")
            fprintf("<strong>Robust Multiple Linear Regression Model | Group "+string(group)+output_heading_days+"</strong>")
            disp(' ')
            disp("dependant:  "+emg_space)
            disp("regressors: " + strjoin(regressors_names+", "))
            disp(' ')
            %disp(coefficient_interpretation)
            disp(mdlr)
            disp("–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––")


            %%
        end
        %%
    case 27 % compare spaces automaticaly
        %%
        fprintf("<strong>compare spaces automaticaly</strong>\n")
        group = input('group: ');
        day   = input('day:   ');

        % measure each space
        spaces = [11 12 2 3 1]; %[9 7 8 6 2 3 1 4 5];

        effects_spaces_table = {};

        for i = 1:length(spaces)
            %% input
            % emg space selector
            space_index = spaces(i);
            emg_spaces = calc_variables.Properties.VariableNames;
            emg_space = emg_spaces{space_index+6};
    
            % other input
            multiple_yn  = 'n'; %input('multiple: ','s');
            days_on_graph = 1; %input('days:     ');
    
            % get subset of calc_variables to be tested
            if days_on_graph == 1
                stencil = (calc_variables.group == group & calc_variables.day == day);
            else
                stencil = (calc_variables.group == group);
            end
    
            calc_variables_subset = calc_variables(stencil,:);
    
            % get observed values from calc_variables_subset
            dependant = calc_variables_subset(:, emg_space);
            dependant = table2array(dependant);
    
            % get regressors
            if multiple_yn == "n"
                regressors_names = "time";
            elseif days_on_graph == 2
                regressors_names = ["day" "session" "trial"];
            else
                regressors_names = ["session" "trial"];
            end
    
            regressors = calc_variables_subset(:, regressors_names);
            regressors_names = regressors.Properties.VariableNames;
            regressors = table2array(regressors);
            mdlr = fitlm(regressors,dependant,'RobustOpts','on');
    
            %%
%             %output
%             if days_on_graph == 2
%                 output_heading_days = " Both Days";
%             else
%                 output_heading_days = " Day "+string(day);
%             end
%             
%             disp(' ')
%             disp("–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––")
%             fprintf("<strong>Robust Multiple Linear Regression Model | Group "+string(group)+output_heading_days+"</strong>")
%             disp(' ')
%             disp("dependant:  "+emg_space)
%             disp("regressors: " + strjoin(regressors_names+", "))
%             disp(' ')
%             %disp(coefficient_interpretation)
%             disp(mdlr)
%             disp("–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––")

            effects_spaces_table(i,:) = {string(emg_space), mdlr.Coefficients{"x1", "Estimate"}, mdlr.Coefficients{"x1", "SE"}, mdlr.NumObservations};

            %%
        end
        effects_spaces_table = cell2table(effects_spaces_table);
        effects_spaces_table.Properties.VariableNames = ["space" "effect" "stderror" "size"];
%         disp(effects_spaces_table)

        %ttest
        ttest_request = ...
        [["fdiApbAdmFcrBic" "fdiApb"];...
        ["fdiApbAdmFcrBic" "fdiApbAdm"];...
        ["fdiApbAdm" "fcrBic"];...
        ["fcrBic" "fdiApbAdm" ];...
        ["fdi" "apb"];...
        ["fcr" "bic"]];

        ttest_results = {};

        for i = 1:height(ttest_request)
            space_a = ttest_request(i,1);
            space_b = ttest_request(i,2);

            x1 = effects_spaces_table{effects_spaces_table.space == space_a, "effect"};
            s1 = effects_spaces_table{effects_spaces_table.space == space_a, "stderror"};
            n1 = effects_spaces_table{effects_spaces_table.space == space_a, "size"};

            x2 = effects_spaces_table{effects_spaces_table.space == space_b, "effect"};
            s2 = effects_spaces_table{effects_spaces_table.space == space_b, "stderror"};
            n2 = effects_spaces_table{effects_spaces_table.space == space_b, "size"};
            
            [t, p] = ttest_manual(x1, s1, n1, x2, s2, n2);
            ttest_results(i,:) = {space_a, space_b, t, p};
        end

        ttest_results = cell2table(ttest_results);
        ttest_results.Properties.VariableNames = ["space a" "space b" "t" "p"];
        disp(ttest_results)
        %%

    case 28 % comparative model for subspaces
        %%
        coefficient_interpretation = table(["intercept"; "x1"], ["x2"; "x3"], ["intercept + x2"; "x1 + x3"],'RowNames',["intercept" "time"]);

        fprintf("<strong>compartive model for subspaces</strong>\n")
        group = input('group: ');
        day   = input('day:   ');
        disp(' ');
        disp('test emg space:');
        emg_space_1 = string(emgSpaceSelector(calc_variables));
        disp(' ');
        disp('base emg space:');
        emg_space_2 = string(emgSpaceSelector(calc_variables));

         % get subset of calc_variables to be tested
        calc_variables_subset = calc_variables( ...
                                    ... get rows according to input
                                    (calc_variables.group == group & calc_variables.day == day), ...for test group
                                    ... get all columns
                                    :);

        % get observed values from calc_variables_subset & create binary
        dependant = calc_variables_subset(:, [emg_space_1 emg_space_2]);
        binary = [ones(height(dependant),1); zeros(height(dependant),1)];
        dependant = [dependant{:,1}; dependant{:,2}];

        % get regressors
        regressors = calc_variables_subset{:, "time"};
        regressors = [regressors; regressors];


        % create intercept terms: dummy*regressor
        intercept_terms = binary.*regressors;


%         intercep_terms =    table(...
%                                     regressors{:,"binary"}.*regressors{:,"time"},...                                    
%                                     'VariableNames', ["binary*time"]...
%                                   ); % end of dummy*regressor creator

        % add intercept terms to regressors
        regressors = [regressors binary intercept_terms];
        
%         regressors_names = regressors.Properties.VariableNames;
%         regressors = table2array(regressors);

        % fit a robust linear regression model
        mdlr = fitlm(regressors,dependant,'RobustOpts','on');

        %output
        coefficient_interpretation.Properties.VariableNames = [emg_space_2 emg_space_1+" vs G"+emg_space_2 emg_space_1];
        disp(' ')
        disp("–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––")
        fprintf("<strong>RMLR - Group "+string(group)+" day "+string(day)+"  "+string(emg_space_1)+" vs "+string(emg_space_2)+"</strong>")
        disp(' ')
        disp("dependant:  "+emg_space_1+" & "+emg_space_2)
        disp("regressors: time, binary, binary.*time")
        disp(' ')
         disp(coefficient_interpretation)
        disp(mdlr)
        disp("–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––")
        %%

    case 30 % view model
        %%
        %% input
        %  √ emg space
        %  √ group
        %  √ multiple or simple
        %  √ 1- or 2- day
        %   √ • which day
        % 

        % emg space selector
        emg_spaces = calc_variables.Properties.VariableNames;
        non_emg_calc_vars = 6;
        disp("  available emg spaces")
        fprintf(' ')
        for i = 1:length(emg_spaces)-non_emg_calc_vars
            fprintf("  "+string(i)+" "+emg_spaces(i+non_emg_calc_vars)+" |")
        end
        fprintf('\n')

        disp(' ')
        emg_space = input('emg space:  ')+6;
        emg_space = emg_spaces{emg_space};

        % other input
        group       = input('group:    ');
        multiple_yn = input('multiple: ','s');
        days_on_graph      = input('days:     ');

        if days_on_graph == 1
            day     = input('day:      ');
        else
            clear day
        end

        % get subset of calc_variables to be tested
        if days_on_graph == 1
            stencil = (calc_variables.group == group & calc_variables.day == day);
        else
            stencil = (calc_variables.group == group);
        end

        calc_variables_subset = calc_variables(stencil,:);

        % get observed values from calc_variables_subset
        dependant = calc_variables_subset(:, emg_space);
        dependant = table2array(dependant);

        % get regressors
        if multiple_yn == "n"
            regressors_names = "time";
        elseif days_on_graph == 2
            regressors_names = ["day" "session" "trial"];
        else
            regressors_names = ["session" "trial"];
        end

        regressors = calc_variables_subset(:, regressors_names);
        
%       NOT RELEVANT UNLESS COMPARING GROUPS
%         add binary dummy regressor
%         binary = array2table(calc_variables_subset.group == test_group & calc_variables_subset.day == test_day, 'VariableNames', "binary");
%         regressors = [regressors binary];
% 
%         % create intercept terms: dummy*regressor
%         intercep_terms =    table(...
%                                     regressors{:,"binary"}.*regressors{:,"session"},...
%                                     regressors{:,"binary"}.*regressors{:,"trial"},...
%                                     'VariableNames', ["binary*session" "binary*trial"]...
%                                   ); % end of dummy*regressor creator
% 
%         % add intercept terms to regressors
%         regressors = [regressors intercep_terms];

        regressors_names = regressors.Properties.VariableNames;
        regressors = table2array(regressors);
        mdlr = fitlm(regressors,dependant,'RobustOpts','on');

        %%
        %output
        if days_on_graph == 2
            output_heading_days = " Both Days";
        else
            output_heading_days = " Day "+string(day);
        end
        
        disp(' ')
        disp("–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––")
        fprintf("<strong>Robust Multiple Linear Regression Model | Group "+string(group)+output_heading_days+"</strong>")
        disp(' ')
        disp("dependant:  "+emg_space)
        disp("regressors: " + strjoin(regressors_names+", "))
        disp(' ')
        %disp(coefficient_interpretation)
        disp(mdlr)
        disp("–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––")
        %%

    
    case 0 % reset cml view
        %%
        clc
        fprintf(operations_list);
        %% end of case 0
    
    case 666 %%Case 666: Terminate Script   
        run_script = 0;
        
    case 911 %Case 911: Clear Workspace
        clearvars -except action fatigue_alldat mean_trials Missing_Trials Parameters rootDir run_script status_update calc_variables lin_reg_models distances_to_calc

end % end of master switch
end % end of master while loop

function emg_space = emgSpaceSelector(calc_variables)
        emg_spaces = calc_variables.Properties.VariableNames;
        non_emg_calc_vars = 6;
        disp("  available emg spaces")
        fprintf(' ')
        for i = 1:length(emg_spaces)-non_emg_calc_vars
            fprintf("  "+string(i)+" "+emg_spaces(i+non_emg_calc_vars)+" |")
        end
        fprintf('\n')

        disp(' ')
        emg_space = input('emg space:  ')+6;
        emg_space = emg_spaces{emg_space};
end