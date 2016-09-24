package mt.edu.um.cs.rv

import org.eclipse.xtext.xbase.compiler.XbaseCompiler
import org.eclipse.xtext.xbase.XExpression
import org.eclipse.xtext.xbase.compiler.output.ITreeAppendable
import javax.inject.Inject
import mt.edu.um.cs.rv.valour.ConditionRefInvocation
import mt.edu.um.cs.rv.valour.ActionRefInvocation
import mt.edu.um.cs.rv.valour.Action
import org.eclipse.xtext.xbase.jvmmodel.IJvmModelAssociations
import org.eclipse.xtext.common.types.JvmGenericType
import org.eclipse.xtext.naming.IQualifiedNameProvider
import java.util.UUID
import mt.edu.um.cs.rv.valour.ActualParameters
import com.google.common.collect.Lists
import com.google.common.base.Function

class ValourCompiler extends XbaseCompiler {

	@Inject extension IJvmModelAssociations
	@Inject extension IQualifiedNameProvider

	override protected doInternalToJavaStatement(XExpression obj, ITreeAppendable appendable, boolean isReferenced) {
		if (obj instanceof ActionRefInvocation) {
			appendable.trace(obj)
			appendable.newLine
			
			val action = obj.actionRef.actionRefId
			val actionParameters = obj.actionActualParameters
			val actionClass = action.jvmElements.filter(JvmGenericType).filter[t|!t.isInterface].head
			val objectName = "action" + uuidName()
			
			appendable.append('''«actionClass.fullyQualifiedName» «objectName» = new «actionClass.fullyQualifiedName»();''')
			appendable.newLine
			
			appendable.append('''«objectName».accept(''')
			appendable.newLine
			
			appendArguments(actionParameters.parameters, appendable)
			
			appendable.newLine
			appendable.append(");")
			appendable.newLine
			
			appendable.newLine
			return
		}
		else if (obj instanceof ConditionRefInvocation) {
			return
		}

		super.doInternalToJavaStatement(obj, appendable, isReferenced)
	}
	
	override void _toJavaExpression(XExpression obj, ITreeAppendable appendable) {
		switch (obj) {
			ConditionRefInvocation: _toJavaExpression(obj as ConditionRefInvocation, appendable)
			default: super._toJavaExpression(obj, appendable)
		}
	}
	
	def _toJavaExpression(ConditionRefInvocation obj, ITreeAppendable appendable) {
			appendable.trace(obj)
			appendable.newLine
			
			val condition = obj.ref.ref
			val conditionParameters = obj.params
			val conditionClass = condition.jvmElements.filter(JvmGenericType).filter[t|!t.isInterface].head
			
			appendable.append('''new «conditionClass.fullyQualifiedName»().apply(''')
			appendable.newLine
			appendArguments(conditionParameters.parameters, appendable)
			appendable.newLine
			appendable.append(")")
			appendable.newLine
			
			appendable.newLine
	}
	
	def uuidName(){
		UUID.randomUUID.toString.replace("-","")
	}
}
