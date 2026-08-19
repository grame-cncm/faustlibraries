"""Faithful Python port of Pink Trombone 1.1's Tract (block-rate updates, lambda-interpolated
reflections, transients, turbulence) and the Glottis LF waveform, used as the reference for
validate.py. Ported line-by-line from the JS at https://dood.al/pinktrombone/ (v1.1, MIT, (c) 2017 Neil Thapen)."""
import math, numpy as np

def clamp(x,lo,hi): return lo if x<lo else hi if x>hi else x
def moveTowards(cur,tgt,up,dn):
    return min(cur+up,tgt) if cur<tgt else max(cur-dn,tgt)

class Tract:
    def __init__(self, sampleRate, blockLength=512, tongueIndex=12.9, tongueDiameter=2.43):
        self.n=44; self.bladeStart=10; self.tipStart=32; self.lipStart=39
        self.glottalReflection=0.75; self.lipReflection=-0.85; self.lastObstruction=-1
        self.fade=1.0; self.movementSpeed=15; self.transients=[]; self.velumTarget=0.01
        self.sampleRate=sampleRate; self.blockTime=blockLength/sampleRate
        n=self.n
        self.diameter=np.zeros(n); self.restDiameter=np.zeros(n); self.targetDiameter=np.zeros(n)
        for i in range(n):
            if i<7*n/44-0.5: d=0.6
            elif i<12*n/44: d=1.1
            else: d=1.5
            self.diameter[i]=self.restDiameter[i]=self.targetDiameter[i]=d
        self.R=np.zeros(n); self.L=np.zeros(n); self.reflection=np.zeros(n+1); self.newReflection=np.zeros(n+1)
        self.junctionOutputR=np.zeros(n+1); self.junctionOutputL=np.zeros(n+1); self.A=np.zeros(n)
        self.noseLength=int(28*n/44); self.noseStart=n-self.noseLength+1
        nl=self.noseLength
        self.noseR=np.zeros(nl); self.noseL=np.zeros(nl); self.noseJunctionOutputR=np.zeros(nl+1)
        self.noseJunctionOutputL=np.zeros(nl+1); self.noseReflection=np.zeros(nl+1); self.noseDiameter=np.zeros(nl); self.noseA=np.zeros(nl)
        for i in range(nl):
            d=2*(i/nl)
            dia = 0.4+1.6*d if d<1 else 0.5+1.5*(2-d)
            self.noseDiameter[i]=min(dia,1.9)
        self.newReflectionLeft=self.newReflectionRight=self.newReflectionNose=0
        self.calculateReflections(); self.calculateNoseReflections()
        self.noseDiameter[0]=self.velumTarget
        # TractUI.init: rest diameter with tongue, diameter=target=rest
        self.tongueIndex=tongueIndex; self.tongueDiameter=tongueDiameter
        self.setRestDiameter()
        for i in range(n): self.diameter[i]=self.targetDiameter[i]=self.restDiameter[i]
        self.lipOutput=0; self.noseOutput=0
    def setRestDiameter(self):
        for i in range(self.bladeStart,self.lipStart):
            t=1.1*math.pi*(self.tongueIndex-i)/(self.tipStart-self.bladeStart)
            ftd=2+(self.tongueDiameter-2)/1.5
            curve=(1.5-ftd+1.7)*math.cos(t)
            if i==self.bladeStart-2 or i==self.lipStart-1: curve*=0.8
            if i==self.bladeStart or i==self.lipStart-2: curve*=0.94
            self.restDiameter[i]=1.5-curve
    def setConstriction(self, index, diameter, active):
        """TractUI.handleTouches constriction part (single constriction)."""
        self.setConstrictions([(index, diameter, active)])
    def setConstrictions(self, touches):
        """TractUI.handleTouches constriction part: list of (index, diameter, active),
        applied in touch order like the JS loop."""
        self.setRestDiameter()
        self.targetDiameter[:]=self.restDiameter
        for (index, diameter, active) in touches:
            if not active: continue
            if diameter < -0.85-0.8: continue
            diameter-=0.3
            if diameter<0: diameter=0
            if index<25: width=10
            elif index>=self.tipStart: width=5
            else: width=10-5*(index-25)/(self.tipStart-25)
            if index>=2 and index<self.n and diameter<3:
                intIndex=round(index)  # JS Math.round rounds .5 up; python banker's - avoid .5
                for i in range(-math.ceil(width)-1, math.ceil(width+1)):
                    if intIndex+i<0 or intIndex+i>=self.n: continue
                    relpos=abs((intIndex+i)-index)-0.5
                    if relpos<=0: shrink=0
                    elif relpos>width: shrink=1
                    else: shrink=0.5*(1-math.cos(math.pi*relpos/width))
                    if diameter<self.targetDiameter[intIndex+i]:
                        self.targetDiameter[intIndex+i]=diameter+(self.targetDiameter[intIndex+i]-diameter)*shrink
    def reshapeTract(self, dt):
        amount=dt*self.movementSpeed; newLast=-1
        for i in range(self.n):
            d=self.diameter[i]; t=self.targetDiameter[i]
            if d<=0: newLast=i
            if i<self.noseStart: sr=0.6
            elif i>=self.tipStart: sr=1.0
            else: sr=0.6+0.4*(i-self.noseStart)/(self.tipStart-self.noseStart)
            self.diameter[i]=moveTowards(d,t,sr*amount,2*amount)
        if self.lastObstruction>-1 and newLast==-1 and self.noseA[0]<0.05:
            self.addTransient(self.lastObstruction)
        self.lastObstruction=newLast
        self.noseDiameter[0]=moveTowards(self.noseDiameter[0],self.velumTarget,amount*0.25,amount*0.1)
        self.noseA[0]=self.noseDiameter[0]**2
    def calculateReflections(self):
        n=self.n
        self.A[:]=self.diameter**2
        for i in range(1,n):
            self.reflection[i]=self.newReflection[i]
            if self.A[i]==0: self.newReflection[i]=0.999
            else: self.newReflection[i]=(self.A[i-1]-self.A[i])/(self.A[i-1]+self.A[i])
        self.reflectionLeft=self.newReflectionLeft; self.reflectionRight=self.newReflectionRight; self.reflectionNose=self.newReflectionNose
        s=self.A[self.noseStart]+self.A[self.noseStart+1]+self.noseA[0]
        self.newReflectionLeft=(2*self.A[self.noseStart]-s)/s
        self.newReflectionRight=(2*self.A[self.noseStart+1]-s)/s
        self.newReflectionNose=(2*self.noseA[0]-s)/s
    def calculateNoseReflections(self):
        self.noseA[:]=self.noseDiameter**2
        for i in range(1,self.noseLength):
            self.noseReflection[i]=(self.noseA[i-1]-self.noseA[i])/(self.noseA[i-1]+self.noseA[i])
    def runStep(self, glottalOutput, turbulenceNoise, lam, turb=None):
        n=self.n; R=self.R; L=self.L; jR=self.junctionOutputR; jL=self.junctionOutputL
        self.processTransients()
        if turb is not None:
            for t in (turb if isinstance(turb, list) else [turb]):
                self.addTurbulenceNoiseAtIndex(*t)
        jR[0]=L[0]*self.glottalReflection+glottalOutput
        jL[n]=R[n-1]*self.lipReflection
        for i in range(1,n):
            r=self.reflection[i]*(1-lam)+self.newReflection[i]*lam
            w=r*(R[i-1]+L[i]); jR[i]=R[i-1]-w; jL[i]=L[i]+w
        i=self.noseStart
        r=self.newReflectionLeft*(1-lam)+self.reflectionLeft*lam
        jL[i]=r*R[i-1]+(1+r)*(self.noseL[0]+L[i])
        r=self.newReflectionRight*(1-lam)+self.reflectionRight*lam
        jR[i]=r*L[i]+(1+r)*(R[i-1]+self.noseL[0])
        r=self.newReflectionNose*(1-lam)+self.reflectionNose*lam
        self.noseJunctionOutputR[0]=r*self.noseL[0]+(1+r)*(L[i]+R[i-1])
        for i in range(n):
            R[i]=jR[i]*0.999; L[i]=jL[i+1]*0.999
        self.lipOutput=R[n-1]
        nl=self.noseLength; nR=self.noseR; nL=self.noseL; njR=self.noseJunctionOutputR; njL=self.noseJunctionOutputL
        njL[nl]=nR[nl-1]*self.lipReflection
        for i in range(1,nl):
            w=self.noseReflection[i]*(nR[i-1]+nL[i]); njR[i]=nR[i-1]-w; njL[i]=nL[i]+w
        for i in range(nl):
            nR[i]=njR[i]*self.fade; nL[i]=njL[i+1]*self.fade
        self.noseOutput=nR[nl-1]
    def finishBlock(self):
        self.reshapeTract(self.blockTime); self.calculateReflections()
    def addTransient(self,position):
        self.transients.append(dict(position=position,timeAlive=0,lifeTime=0.2,strength=0.3,exponent=200))
    def processTransients(self):
        for tr in self.transients:
            amp=tr['strength']*2**(-tr['exponent']*tr['timeAlive'])
            self.R[tr['position']]+=amp/2; self.L[tr['position']]+=amp/2
            tr['timeAlive']+=1.0/(self.sampleRate*2)
        self.transients=[t for t in self.transients if t['timeAlive']<=t['lifeTime']]
    def addTurbulenceNoiseAtIndex(self, turbulenceNoise, index, diameter, noiseModulator):
        i=math.floor(index); delta=index-i
        turbulenceNoise*=noiseModulator
        thin=clamp(8*(0.7-diameter),0,1); openn=clamp(30*(diameter-0.3),0,1)
        n0=turbulenceNoise*(1-delta)*thin*openn; n1=turbulenceNoise*delta*thin*openn
        for (k,v) in ((i+1,n0),(i+2,n1)):
            if k<self.n:
                self.R[k]+=v/2; self.L[k]+=v/2

def lf_params(tenseness):
    Rd=3*(1-tenseness); Rd=clamp(Rd,0.5,2.7)
    Ra=-0.01+0.048*Rd; Rk=0.224+0.118*Rd; Rg=(Rk/4)*(0.5+1.2*Rk)/(0.11*Rd-Ra*(0.5+1.2*Rk))
    Ta=Ra; Tp=1/(2*Rg); Te=Tp+Tp*Rk; eps=1/Ta; shift=math.exp(-eps*(1-Te)); Delta=1-shift
    RHS=((1/eps)*(shift-1)+(1-Te)*shift)/Delta
    tl=-(Te-Tp)/2+RHS; tu=-tl; omega=math.pi/Tp; s=math.sin(omega*Te)
    y=-math.pi*s*tu/(Tp*2); z=math.log(y); alpha=z/(Tp/2-Te); E0=-1/(s*math.exp(alpha*Te))
    return dict(alpha=alpha,E0=E0,eps=eps,shift=shift,Delta=Delta,Te=Te,omega=omega)
def lf_wave(t,p):
    if t>p['Te']: return (-math.exp(-p['eps']*(t-p['Te']))+p['shift'])/p['Delta']
    return p['E0']*math.exp(p['alpha']*t)*math.sin(p['omega']*t)

def run_tract(sr, glottal, blockLength=512, tongueIndex=12.9, tongueDiameter=2.43, constriction=None,
              constrictions=None, noise=None, noiseMod=0.3):
    """glottal: array. constriction: (index, diameter, activeArrayPerBlock or bool), or
    constrictions: list of those (multi-touch). Returns output array."""
    T=Tract(sr,blockLength,tongueIndex,tongueDiameter)
    N=len(glottal); out=np.zeros(N)
    nblocks=int(math.ceil(N/blockLength))
    clist = constrictions if constrictions is not None else ([constriction] if constriction is not None else [])
    for b in range(nblocks):
        touches=[]
        for (cidx,cdia,acts) in clist:
            act = acts[b] if hasattr(acts,'__len__') else acts
            touches.append((cidx,cdia,act))
        T.setConstrictions(touches)
        # noise intensity fade in/out (fricative_intensity) handled by caller via noise array
        for j in range(blockLength):
            k=b*blockLength+j
            if k>=N: break
            l1=j/blockLength; l2=(j+0.5)/blockLength
            g=glottal[k]
            turbs=[(0.66*noise[k], cidx, cdia, noiseMod)
                   for (cidx,cdia,act) in touches
                   if noise is not None and act and cdia>0 and 2<=cidx<=T.n]
            v=0
            T.runStep(g,0,l1,turbs); v+=T.lipOutput+T.noseOutput
            T.runStep(g,0,l2,turbs); v+=T.lipOutput+T.noseOutput
            out[k]=v*0.125
        T.finishBlock()
    return out
