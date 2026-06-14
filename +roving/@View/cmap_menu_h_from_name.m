function menu_h=cmap_menu_h_from_name(self,cmap_name)

% Returns the handle of the Color-menu item for the colormap named
% cmap_name, without using eval().
if strcmp(cmap_name,'gray') ,
  menu_h=self.gray_menu_h;
elseif strcmp(cmap_name,'bone') ,
  menu_h=self.bone_menu_h;
elseif strcmp(cmap_name,'hot') ,
  menu_h=self.hot_menu_h;
elseif strcmp(cmap_name,'parula') ,
  menu_h=self.parula_menu_h;
elseif strcmp(cmap_name,'jet') ,
  menu_h=self.jet_menu_h;
elseif strcmp(cmap_name,'red_green') ,
  menu_h=self.red_green_menu_h;
elseif strcmp(cmap_name,'red_blue') ,
  menu_h=self.red_blue_menu_h;
else
  error('View:noSuchColormapMenu', ...
        'No colormap menu item named %s',cmap_name);
end

end
