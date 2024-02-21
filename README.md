# ProcessBasedModelling.jl

[![docsdev](https://img.shields.io/badge/docs-dev-lightblue.svg)](https://juliadynamics.github.io/ProcessBasedModelling.jl/dev/)
[![docsstable](https://img.shields.io/badge/docs-stable-blue.svg)](https://juliadynamics.github.io/ProcessBasedModelling.jl/stable/)
[![CI](https://github.com/JuliaDynamics/ProcessBasedModelling.jl/workflows/CI/badge.svg)](https://github.com/JuliaDynamics/ProcessBasedModelling.jl/actions?query=workflow%3ACI)
[![codecov](https://codecov.io/gh/JuliaDynamics/ProcessBasedModelling.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/JuliaDynamics/ProcessBasedModelling.jl)
[![Package Downloads](https://shields.io/endpoint?url=https://pkgs.genieframework.com/api/v1/badge/ProcessBasedModelling)](https://pkgs.genieframework.com?packages=ProcessBasedModelling)

ProcessBasedModelling.jl is an extension to [ModelingToolkit.jl](https://docs.sciml.ai/ModelingToolkit/stable/) (MTK) for building a model of equations using symbolic expressions.
It is an alternative framework to MTK's [native component-based modelling](https://docs.sciml.ai/ModelingToolkit/stable/tutorials/acausal_components/), but, instead of components, there are "processes".
This approach is useful in the modelling of physical/biological/whatever systems, where each variable corresponds to a particular physical concept or observable and there are few (or none) duplicate variables to make the definition of MTK "factories" worthwhile.
On the other hand, there plenty of different physical representations, or _processes_ to represent a given physical concept.
In many scientific fields this approach parallels the modelling reasoning of the researcher more closely than the "components" approach.

Beyond this reasoning style, the biggest strength of ProcessBasedModelling.jl is the **informative errors and automation** it provides regarding incorrect/incomplete equations. When building the MTK model via ProcessBasedModelling.jl the user provides a vector of "processes": equations or custom types that have a well defined and single left-hand-side variable.
This allows ProcessBasedModelling.jl to:

1. Iterate over the processes and collect _new_ variables that have been introduced by a provided process but do not themselves have a process assigned to them.
2. For these collected "process-less" variables:
   - If there is a default process defined, incorporate this one into the model
   - If there is no default process but the variable has a default value, equate the variable to a _parameter_ that has the same default value and throw an informative warning.
   - Else, throw an informative error saying exactly which originally provided variable introduced this new "process-less" variable.
3. Throw an informative error if a variable has two processes assigned to it (by mistake).

In our experience, and as we also highlight explicitly in the online documentation, this approach typically yields simpler, less ambiguous and more targeted warning or error messages than the native MTK one's, leading to faster identification and resolution of the problems with the composed equations.

ProcessBasedModelling.jl is particularly suited for developing a model about a physical/biological/whatever system and being able to try various physical "rules" (couplings, feedbacks, mechanisms, ...) for a given physical observable efficiently.
This means switching arbitrarily between different processes that correspond to the same variable.
Hence, the target application of ProcessBasedModelling.jl is to be a framework to develop field-specific libraries that offer predefined processes without themselves relying on the existence of context-specific predefined components. An example usage is in [EnergyBalanceModels.jl](https://github.com/JuliaDynamics/EnergyBalanceModels.jl).

Besides the informative errors, ProcessBasedModelling.jl also

1. Provides a couple of common process subtypes out of the box to accelerate development of field-specific libraries.
2. Makes named MTK variables and parameters automatically, corresponding to parameters introduced by the by-default provided processes. This typically leads to intuitive names without being explicitly coded, while being possible to opt-out.
3. Provides some utility functions for further building field-specific libraries.

See the documentation online for details on how to use this package as well as examples highlighting its usefulness.
