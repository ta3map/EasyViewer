classdef Session < handle

    % SESSION - class representing an OpenEphys session.
    % Each 'Session' object represents a top-level directory containing data from
    % one or more Record Nodes.

    properties
        directory   % Root directory containing the record nodes
        recordNodes % Array of all the record nodes corresponding to this session
    end

    methods 
        function self = Session(directory) 
            % Constructor for the Session class
            self.directory = directory;
            Utils.log("Searching directory: ", directory);
            self.recordNodes = {};
            self.detectRecordNodes();
        end

        function self = detectRecordNodes(self)
            % Check if 'settings.xml' exists in the root directory
            settingsFile = fullfile(self.directory, 'settings.xml');
            
            if exist(settingsFile, 'file') == 2
                % If 'settings.xml' is found, treat this folder as a Record Node
                Utils.log("Found settings.xml, treating the directory as a Record Node: ", self.directory);
                self.recordNodes{end+1} = RecordNode(self.directory);
            else
                % Otherwise, search for 'Record Node *' directories
                paths = glob(fullfile(self.directory, 'Record Node *'));

                if isempty(paths)
                    Utils.log("No Record Node folders found.");
                else
                    for i = 1:length(paths)
                        self.recordNodes{end+1} = RecordNode(paths{i});
                    end
                end
            end
        end

        function show(self)
            % Display information about all record nodes in the session
            for i = 1:length(self.recordNodes)
                node = self.recordNodes{i};
                fprintf("(%d) %s : %s Format \n", i, node.name, node.format);
            end
        end
    end
end
