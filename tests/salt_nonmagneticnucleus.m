function ok = test(opt)

% Test whether salt() can handle single-isotope systems
% with a non-magnetic nucleus

Sys.Nucs = '12C';
Sys.A = 10;
Sys.lwEndor = 1;

Exp.Field = 350;
Exp.Range = [0 50];

[rf,spec] = salt(Sys,Exp);

if opt.Display
  plot(rf,spec);
end

ok = all(spec(:)==0);
