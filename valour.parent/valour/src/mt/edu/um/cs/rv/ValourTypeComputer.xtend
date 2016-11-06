package mt.edu.um.cs.rv

import mt.edu.um.cs.rv.valour.ActionRefInvocation
import org.eclipse.xtext.xbase.typesystem.computation.ITypeComputationState
import org.eclipse.xtext.xbase.typesystem.computation.XbaseTypeComputer
import org.eclipse.xtext.xbase.XExpression
import mt.edu.um.cs.rv.valour.ConditionRefInvocation
import mt.edu.um.cs.rv.valour.MonitorTriggerFire

//http://stackoverflow.com/questions/34434562/xtext-get-content-compiled-value-of-xexpression
//https://www.eclipse.org/forums/index.php/t/1080930/
class ValourTypeComputer extends XbaseTypeComputer  {
		
	def dispatch computeTypes(ActionRefInvocation literal, ITypeComputationState state) {
        for (XExpression ap : literal.getActionActualParameters().getParameters()) {
			state.withNonVoidExpectation().computeTypes(ap);
		}
        
        state.acceptActualType(getPrimitiveVoid(state))
    }
    
    def dispatch computeTypes(MonitorTriggerFire literal, ITypeComputationState state) {
        for (XExpression ap : literal.monitorTriggerActualParameters.getParameters()) {
			state.withNonVoidExpectation().computeTypes(ap);
		}
        
        state.acceptActualType(getPrimitiveVoid(state))
    }
    
    def dispatch computeTypes(ConditionRefInvocation literal, ITypeComputationState state) {
        for (XExpression ap : literal.params.getParameters()) {
			state.withNonVoidExpectation().computeTypes(ap);
		}

     	val booleanLightWeightRef = getTypeForName(Boolean.TYPE, state)
     	
        state.withExpectation(booleanLightWeightRef)
        state.acceptActualType(booleanLightWeightRef)
    }

}