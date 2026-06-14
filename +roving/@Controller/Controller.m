classdef Controller < handle

  properties
    model;  % the model
    view;  % the view
    card_birth_roi_next;  % the cardinality of the next ROI to be created
                          % e.g. if the next one will be the 1st one, this
                          % would be one
    %shift_depressed;  % boolean, whether any shift keys are depressed
    % Test-mode dialog support, used to drive the app headlessly from the test
    % suite.  In normal use is_in_test_mode is false and the dialog wrapper
    % methods (uigetfile/uiputfile/inputdlg/errordlg) just call the real
    % builtins, so interactive operation is unaffected.  When it is true the
    % wrappers instead consume canned answers from dialog_responses (a FIFO
    % queue the test fills before invoking a method that pops up a dialog) and
    % append the text of any errordlg to dialog_messages (so the test can
    % assert on it).  See the dialog wrappers below.
    is_in_test_mode = false;
    dialog_responses = {};
    dialog_messages = {};
  end  % properties
  
  properties (Dependent=true)
    roi_list
  end
  
  methods
    function self=Controller(varargin)
      % Leave the model empty until we load data
      self.model=roving.Model();

      % Make the view
      self.view=roving.View(self,self.model);

      % Init the ROI counter, etc.
      self.card_birth_roi_next=[];
      %self.shift_depressed=false;  % probably
      
      % load the data, if given an arg
      if nargin>=1
        if ischar(varargin{1})
          file_name=varargin{1};
          self.open_video_given_file_name(file_name);
        end
      end
    end  % constructor

    % --- dialog wrappers -------------------------------------------------
    % Each forwards to the real builtin in normal use; in test mode it returns
    % a queued response (input dialogs) or records what would have been shown
    % (errordlg).  See the test-mode properties above.

    function [filename,pathname,filterindex]=uigetfile(self,varargin)
      if self.is_in_test_mode
        r=self.pop_dialog_response();
        filename=r{1};
        pathname=r{2};
        if numel(r)>=3, filterindex=r{3}; else, filterindex=1; end
      else
        [filename,pathname,filterindex]=uigetfile(varargin{:});
      end
    end

    function [filename,pathname,filterindex]=uiputfile(self,varargin)
      if self.is_in_test_mode
        r=self.pop_dialog_response();
        filename=r{1};
        pathname=r{2};
        if numel(r)>=3, filterindex=r{3}; else, filterindex=1; end
      else
        [filename,pathname,filterindex]=uiputfile(varargin{:});
      end
    end

    function answer=inputdlg(self,varargin)
      % In test mode the queued response is the cell to return ({} = "Cancel"),
      % or the sentinel [] meaning "accept the dialog's prefilled defaults" --
      % i.e. return its definput argument (the 4th).
      if self.is_in_test_mode
        answer=self.pop_dialog_response();
        if isnumeric(answer) && isempty(answer) && numel(varargin)>=4
          answer=varargin{4};
        end
      else
        answer=inputdlg(varargin{:});
      end
    end

    function errordlg(self,message,varargin)
      % (the builtin returns a handle, but no caller in this app uses it)
      if self.is_in_test_mode
        self.dialog_messages{end+1}=message;
      else
        errordlg(message,varargin{:});
      end
    end

    function r=pop_dialog_response(self)
      % Pop the next queued response for an input dialog (uigetfile/inputdlg/..).
      if isempty(self.dialog_responses)
        error('roving:Controller:noDialogResponse', ...
              'a dialog was shown in test mode but dialog_responses is empty');
      end
      r=self.dialog_responses{1};
      self.dialog_responses=self.dialog_responses(2:end);
    end

  end  % methods

  methods (Access=private)
  end  % methods
  
end  % classdef
