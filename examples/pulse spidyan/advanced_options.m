% advanced options for spindynamics (spidyan)
%==========================================================================
% demonstration of some of the advanced options in spidyan and how to use
% them

clear

% Default Spin System
Sys.S = 1/2;
Sys.ZeemanFreq = 33.500; % GHz
Sys.T1 = 1; % us
Sys.T2 = 0.5; % us

% Pulse Definitions
Rectangular.Type = 'rectangular';
Rectangular.tp = 0.02; % us
Rectangular.Flip = pi/2; %rad

Adiabatic.Type = 'quartersin/linear';
Adiabatic.Flip = pi/2; % rad
Adiabatic.tp = 0.2; % us
Adiabatic.trise = 0.05; % us
Adiabatic.Qcrit = 5; % critical adiabaticity  
Adiabatic.Frequency = [-50 50]; % frequency band,MHz

% A default Experiment/Sequence
Exp.mwFreq = 33.5; % GHz
Exp.DetOperator = {'z1'};

%% 1) Using a custom initial state and equilibrium state:
% The spin relaxes to from the provided initial state to the equilibrium

Sys_ = Sys;
Sys_.initState = +sop(Sys_.S,'z');
Sys_.eqState = -sop(Sys_.S,'z');

Exp_ = Exp;
Exp_.Sequence = {Rectangular 5}; % pulse and 5 mus free evolution


Opt_.Relaxation = [0 1]; 

[TimeAxis, Signal] = spidyan(Sys_,Exp_,Opt_);

% plotting
figure(1)
clf
plot(TimeAxis*1000,real(Signal))
xlabel('t (ns)')
ylabel('<S_i>')
legend(Exp.DetOperator)

%% 2) complex excitation operators
% Complex excitation operators allows to investigate Bloch Siegert shifts
% If ComplexExcitation is active, the excitation operator takes the form:
% real(IQ)*Sx + imag(IQ)*Sy

Sys_ = Sys;

Exp_ = Exp;
Exp_.Sequence = {Adiabatic};

[TimeAxis, Regular] = spidyan(Sys_,Exp_);

Opt_ = [];
Opt_.ComplexExcitation = 1;
[~, ComplexExOp] = spidyan(Sys_,Exp_,Opt_);

% plotting
figure(2)
clf
hold on
plot(TimeAxis*1000,Regular)
plot(TimeAxis*1000,ComplexExOp)
xlabel('t (ns)')
ylabel('<S_i>')
legend('Regular ExOp','Complex ExOp')

%% 3) custom excitation operators
% With custom excitation operators it is possible to investigate the effect
% of pulses during a pulse sequence in more detail - in this example our
% custom excitation operator is the same as the default one (Sx), but 
% manually defined (sop(Sys.S,'x') would also be possible. 
% Feel free to experiment!

Opt_ = [];
Opt_.ExcOperator = {sop(Sys_.S,'x(1|2)')};

[TimeAxis, Custom] = spidyan(Sys_,Exp_,Opt_);

plot(TimeAxis*1000,Custom)
legend('Regular ExOp','Complex ExOp','Custom ExOp')

% It is also possible to combine ComplexExcitation with custom excitation 
% operators
% In this case the excitation operator takes the form:
% real(IQ)*real(ExOperator) + imag(IQ)*imag(ExOperator)

Opt_ = [];
Opt_.ExcOperator = {sop(Sys_.S,'x(1|2)')+sop(Sys_.S,'y(1|2)')};
Opt_.ComplexExcitation = 1;

[TimeAxis, Custom] = spidyan(Sys_,Exp_,Opt_);

plot(TimeAxis*1000,Custom)
legend('Regular ExOp','Complex ExOp','Custom ExOp','Complex custom ExOp')

%% 3) state trajectories
% if state trajectories is switched on for an event, density matrices at
% each propagation point are stored and returned

Sys_ = Sys;
Exp_ = Exp;
Opt_ = [];

% Switches on state trajectories for both events
Opt_.StateTrajectories = [1 1];

Exp_.Sequence = {Adiabatic 0.5};

[TimeAxis, Signal, AdvancedOutputs] = spidyan(Sys_,Exp_,Opt_);

message = ['Cell array ''AdvancedOutputs.StateTrajectories'' contains ' num2str(size(AdvancedOutputs.StateTrajectories,2)) ' density matrices.'];
disp(message)