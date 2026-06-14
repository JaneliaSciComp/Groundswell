function set_cmap_name(self,new_cmap_name)

% need to remember the old cmap_name so that we can
% uncheck that menu item
old_cmap_name=self.cmap_name;

% set the chosen cmap_name
self.cmap_name=new_cmap_name;

% uncheck the old menu item
menu_h=self.cmap_menu_h_from_name(old_cmap_name);
set(menu_h,'Checked','off');

% check the new menu item
menu_h=self.cmap_menu_h_from_name(new_cmap_name);
set(menu_h,'Checked','on');

% set the colormap
cmap=roving.colormap_from_name(new_cmap_name);
set(self.figure_h,'colormap',cmap);
