package mt.edu.um.cs.rv

import org.eclipse.xtext.xbase.util.XExpressionHelper
import org.eclipse.xtext.xbase.XExpression
import mt.edu.um.cs.rv.valour.ActionRefInvocation
import mt.edu.um.cs.rv.valour.ConditionRefInvocation
import mt.edu.um.cs.rv.valour.MonitorTriggerFire

class ValourXExpressionHelper extends XExpressionHelper{
	override hasSideEffects(XExpression expr) {
        if (expr instanceof ActionRefInvocation || expr.eContainer instanceof ActionRefInvocation) {
            return true
        }
        else if (expr instanceof MonitorTriggerFire || expr.eContainer instanceof MonitorTriggerFire) {
            return true
        }
        else if (expr instanceof ConditionRefInvocation || expr.eContainer instanceof ConditionRefInvocation) {
            return true
        }
        super.hasSideEffects(expr)
    }
	
}