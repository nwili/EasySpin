function [err,data] = test(opt,olddata)

% Stevens op. for multi-spin system: Check dimension
%======================================================
Spins = [3/2 3 5/2 3/2 4];
iSpin = 2;
k = 4; q = +3;
Op = stev(Spins,k,q,iSpin);
err = size(Op,1)~=prod(2*Spins+1);
data = [];