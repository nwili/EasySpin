function [nBasisFunctions,nSpatialBasisFunctions,Indices] = chili_basiscount(Basis,Sys)

DirTilt = Basis.DirTilt;

evenLmax = Basis.evenLmax;
oddLmax = Basis.oddLmax;

jKmin = Basis.jKmin;
Kmax = Basis.Kmax;
deltaK = Basis.deltaK;

Mmax = Basis.Mmax;

pSmin = Basis.pSmin;
pImax = Basis.pImax;
pI1max = pImax; pI2max = pImax;

MpSymm = Basis.MpSymm;

I = Sys.I;
nNuclei = numel(I);
if nNuclei>=1, I1 = I(1); end
if nNuclei>=2, I2 = I(2); end

iRow = 0;
iSpatial = 0;

MakeIndices = 1;

if MakeIndices
  nRowBlock = 20000;
  Indices = zeros(nRowBlock,4+2+2*nNuclei);
end

for L = 0:evenLmax
  Lparity = parity(L);
  evenL = (Lparity==1);
  if (~evenL) && (L>oddLmax), continue; end    
  for jK = jKmin:2:1
    for K = 0:deltaK:min(L,Kmax)
      if ((K==0) && (Lparity~=jK)), continue; end
      Mmx = min(L,Mmax);
      for M = -Mmx:Mmx
        iSpatial = iSpatial + 1;


        for pS = pSmin:1
          qSmx = 1 - abs(pS);
          for qS = -qSmx:2:qSmx

            % no nuclei ---------------------------------------
            if (nNuclei==0)
              if (MpSymm&&(~DirTilt)&&((pS-1)~=M)), continue; end % Meirovitch Eq.(A47)
              
              iRow = iRow + 1;
              if MakeIndices
                Indices(iRow,:) = [L jK K M pS qS];
              end
                
            % one nucleus ---------------------------------------
            elseif (nNuclei==1)
              
              for pI1 = -pI1max:pI1max
                if (MpSymm&&(~DirTilt)&&((pI1+pS-1)~=M)), continue; end % Meirovich Eq.(A47)
                qI1max = 2*I1 - abs(pI1);
                for qI1 = -qI1max:2:qI1max
                  
                  iRow = iRow + 1;
                  if MakeIndices
                    Indices(iRow,:) = [L jK K M pS qS pI1 qI1];
                  end
                  
                end % qI
              end % pI
              
            % two nuclei ---------------------------------------
            elseif (nNuclei==2)
              
              for pI1 = -pI1max:pI1max
                qI1max = 2*I1 - abs(pI1);
                for qI1 = -qI1max:2:qI1max
                  for pI2 = -pI2max:pI2max
                    if MpSymm && (~DirTilt) && (pI1+pI2+pS-1~=M), continue; end % Meirovich Eq.(A47)
                    qI2max = 2*I2 - abs(pI2);
                    for qI2 = -qI2max:2:qI2max
                      
                      iRow = iRow + 1;
                      if MakeIndices
                        Indices(iRow,:) = [L jK K M pS qS pI1 qI1 pI2 qI2];
                      end
                      
                    end % qI2
                  end % pI2
                end % qI1
              end % pI1

            end
            
          end % qS
        end % pS

      end % M
    end % K
  end % jK
end % L
Indices  = Indices(1:iRow,:);

nBasisFunctions = iRow;
nSpatialBasisFunctions = iSpatial;

return
%==================================================================

function p = parity(a)
if (mod(a,2)==0), p = +1; else p = -1; end
return