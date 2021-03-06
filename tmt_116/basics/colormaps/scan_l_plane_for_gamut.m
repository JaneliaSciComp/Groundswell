n_samples=201;
L=75;
%L=53;
%L=35;
a_grid=linspace(-150,150,n_samples)';
b_grid=linspace(-150,150,n_samples);
a_mesh=repmat(a_grid,[1 n_samples]);
b_mesh=repmat(b_grid,[n_samples 1]);
a=reshape(a_mesh,[n_samples^2 1]);
b=reshape(b_mesh,[n_samples^2 1]);
lab=[repmat(L,[n_samples^2 1]) a b];
in_gamut=lab_in_gamut(lab);
in_gamut_mesh=reshape(in_gamut,[n_samples n_samples]);

figure;
surface(a_mesh,b_mesh,double(in_gamut_mesh),'EdgeColor','none');
%colorbar;
xlabel('a');
ylabel('b');
title(sprintf('L = %.0f',L));
axis square;
