package mt.edu.um.cs.rv

import org.eclipse.xtext.xbase.util.XExpressionHelper
import org.eclipse.xtext.xbase.XExpression
import mt.edu.um.cs.rv.valour.ActionRef
import mt.edu.um.cs.rv.valour.ActionRefInvocation

class ValourXExpressionHelper extends XExpressionHelper{
	override hasSideEffects(XExpression expr) {
        if (expr instanceof ActionRefInvocation || expr.eContainer instanceof ActionRefInvocation) {
            return true
        }
        super.hasSideEffects(expr)
    }
	
}