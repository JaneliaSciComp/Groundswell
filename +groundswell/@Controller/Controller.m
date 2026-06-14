classdef Controller < handle
% This is Controller, a class to represent the 
% controller for the main window of the groundswell application.

properties
  model;
  view;
  fs_str;  % string holding the sampling rate, in Hz
%   command_depressed;  % boolean, whether any mac command keys are depressed
%                       % undefined if not running on a macs
  % Test-mode dialog support, used to drive the app headlessly from the test
  % suite.  In normal use is_in_test_mode is false and the dialog wrapper methods
  % (uigetfile/inputdlg/questdlg/errordlg/...) just call the real builtins, so
  % interactive operation is unaffected.  When it is true the wrappers instead
  % consume canned answers from dialog_responses (a FIFO queue the test fills
  % before invoking a method that pops up a dialog) and append the text of any
  % errordlg/warndlg/msgbox to dialog_messages (so the test can assert on it).
  % Audio played via audioplayer() is likewise recorded into played_audio
  % rather than sent to a device.
  is_in_test_mode = false;
  dialog_responses = {};
  dialog_messages = {};
  played_audio = {};
end  % properties

methods
  function self=Controller(varargin)
    self.fs_str='';
    self.model=[];
    self.view=groundswell.View(self);
%    self.command_depressed=false;  % probably
    % load the data, if given an arg
    if nargin==1 && ischar(varargin{1})
      filename=varargin{1};
      [~,~,ext]=fileparts(filename);
      if strcmp(ext,'.tcs')
        self.open(filename);
      else
        self.import(filename);
      end
    end
  end  % constructor

  function center(self)
    self.model.center(self.view.i_selected);
    self.view.traces_changed();
  end 

  function rectify(self)
    self.model.rectify(self.view.i_selected);
    self.view.traces_changed();
  end

  function dx_over_x(self)
    self.model.dx_over_x(self.view.i_selected);
    % update the view
    self.view.traces_changed();
    self.view.units_changed();
    % go ahead and re-optimize the y ranges of the modified traces, 
    % because they've almost certainly moved out-of-range
    self.optimize_selected_y_axis_ranges();  % re-optimize range.
  end

  % --- dialog wrappers ---------------------------------------------------
  % Each forwards to the real builtin in normal use; in test mode it returns a
  % queued response (input dialogs) or records what would have been shown
  % (errordlg/warndlg/msgbox).  See the test-mode properties above.

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
    % i.e. return its definput argument (the 4th), so a test needn't restate
    % every default value.
    if self.is_in_test_mode
      answer=self.pop_dialog_response();
      if isnumeric(answer) && isempty(answer) && numel(varargin)>=4
        answer=varargin{4};
      end
    else
      answer=inputdlg(varargin{:});
    end
  end

  function button=questdlg(self,varargin)
    if self.is_in_test_mode
      button=self.pop_dialog_response();  % the chosen button string
    else
      button=questdlg(varargin{:});
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

  function warndlg(self,message,varargin)
    if self.is_in_test_mode
      self.dialog_messages{end+1}=message;
    else
      warndlg(message,varargin{:});
    end
  end

  function msgbox(self,message,varargin)
    if self.is_in_test_mode
      self.dialog_messages{end+1}=message;
    else
      msgbox(message,varargin{:});
    end
  end

  function player=audioplayer(self,y,fs,varargin)
    % In test mode record the (signal, rate) and return [] -- callers guard
    % playblocking() on a non-empty player, so no audio device is touched.
    if self.is_in_test_mode
      self.played_audio{end+1}={y,fs};
      player=[];
    else
      player=audioplayer(y,fs,varargin{:});
    end
  end

  function r=pop_dialog_response(self)
    % Pop the next queued response for an input dialog (uigetfile/inputdlg/...).
    if isempty(self.dialog_responses)
      error('groundswell:Controller:noDialogResponse', ...
            'a dialog was shown in test mode but dialog_responses is empty');
    end
    r=self.dialog_responses{1};
    self.dialog_responses=self.dialog_responses(2:end);
  end
end  % methods
  
end  % classdef
