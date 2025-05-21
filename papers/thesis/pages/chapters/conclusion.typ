#import "../../util/macros.typ": *

= Conclusion
== Future work <chap:futurework>
Throughout the duration of this thesis, there have been a number of improvements and areas for future research
identified.

Firstly, in future work, it would be very important to address a number of limitations in the TaMaRa
algorithm. At this point, the algorithm is unfortunately unable to handle a number of critical circuits,
particularly circuits types that are commonly used in industry designs. This includes many (but not all)
circuits which use sequential elements such as DFFs, recurrent circuits, and a small number of combinatorial
circuits with very complex bit swizzling. The critical flaw that causes this is the lack of robustness of the
wiring stage (@sec:wiring and @sec:wiringfixup). As an abstraction over any and all circuits at various levels
of the design process, RTLIL is extremely complex, and hence splicing an RTLIL netlist to insert majority
voters in all of these cases is very challenging. #TODO("more on this")

Likewise, there are some limitations in the verification methodology that need to be addressed. Whilst I do
believe that the verification proofs are strong for the circuits we were able to prove, there are a number of
circuits that I was unable to prove. Particularly, this includes circuits that use sequential logic elements,
particularly DFFs. The issue is an unexpected result when injecting numerous faults into the circuit. As shown
in Figure XX, after a certain number of faults, even an unmitigated circuit (without any TMR at all!) is
apparently able to mitigate 100% of faults. This is a result that should not be possible, and is likely a
methodological error caused by the sheer number of faults being introduced into a small circuit being
cancelling each other out. #TODO("but we can't do more complkicated circuits")

#TODO("solution to L21 method.typ")
