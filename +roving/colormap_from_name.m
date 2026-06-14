function cmap=colormap_from_name(cmap_name)

% Returns the 256-entry colormap named by cmap_name, without using eval().
if strcmp(cmap_name,'red_green') ,
  % feval doesn't work with imported functions?
  cmap=roving.red_green(256);
elseif strcmp(cmap_name,'red_blue') ,
  % feval doesn't work with imported functions?
  cmap=roving.red_blue(256);
else
  % (Formerly substituted jet for parula on pre-R2014b MATLAB via verLessThan;
  % removed -- parula exists in every supported release, and the verLessThan
  % call breaks under R2026a via the tmt_116/basics/pad.m shadow of builtin pad.)
  cmap=feval(cmap_name,256);
end

end
