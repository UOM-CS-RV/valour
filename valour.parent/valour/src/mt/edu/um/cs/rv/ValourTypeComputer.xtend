package mt.edu.um.cs.rv

import mt.edu.um.cs.rv.valour.ActionRefInvocation
import org.eclipse.xtext.xbase.typesystem.computation.ITypeComputationState
import org.eclipse.xtext.xbase.typesystem.computation.XbaseTypeComputer

//http://stackoverflow.com/questions/34434562/xtext-get-content-compiled-value-of-xexpression
class ValourTypeComputer extends XbaseTypeComputer  {
	def dispatch computeTypes(ActionRefInvocation literal, ITypeComputationState state) {
//        state.withNonVoidExpectation.computeTypes(literal.obj)
		state.withoutExpectation
        state.acceptActualType(getPrimitiveVoid(state))
    }
}