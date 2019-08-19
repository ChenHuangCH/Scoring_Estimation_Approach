# Scoring_Estimation_Approach

This repository provides the Scoring estimation approach implemented in Matlab that can be used to estimate ground-motion model with certain spatial correlation structure, such as
* Isotropic and stationary spatial correlation: exponential, squared exponential, Mat&eacute;rn with &nu;=1.5
* Anisotropic and stationary spatial correlation: exponential with inter-station distance along fault-normal (FN) and fault-parallel (FP) directions

<img src="https://latex.codecogs.com/svg.latex?\small&space;\begin{align*}&space;k(d)=\exp\left(-\frac{\sqrt{d_{FP}^2+\theta&space;d_{FN}^2}}{h}\right)&space;\end{align*}" />

where the positive range parameter is h in FP direction and <img src="https://latex.codecogs.com/svg.latex?\small&space;{h}/{\sqrt{\theta}}" /> in FN direction .

Further information can be found in the following papers:

>[Huang, C., and Galasso, C. (2019). "Ground-motion intensity measure correlations observed in Italian data", Earthquake Engineering and Structural Dynamics (Accepted/in press)]()

>[Ming, D., Huang, C., Peters, G., Galasso, C (2019). "An advanced estimation algorithm for ground-motion models with spatial correlation", Bulletin of the Seismological Society of America, 2019, 109(2): 541-566.](https://pubs.geoscienceworld.org/ssa/bssa/article-abstract/568974/an-advanced-estimation-algorithm-for-ground-motion?redirectedFrom=fulltext)
