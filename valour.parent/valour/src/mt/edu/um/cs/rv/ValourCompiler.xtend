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
			val objectName = "action" + uuidName
			
			appendable.append('''«actionClass.fullyQualifiedName» «objectName» = new «actionClass.fullyQualifiedName»();''')
			appendable.newLine
			
			appendable.append('''«objectName».accept(''')
			appendable.newLine
			
			appendArguments(actionParameters.parameters, appendable)
			
			appendable.append(");")
			appendable.newLine
			
			appendable.newLine
			return
		}

		super.doInternalToJavaStatement(obj, appendable, isReferenced)
	}

	def functionCall(Action action, ActualParameters actualParameters, ITreeAppendable appendable, boolean isReferenced) {
		val actionClass = action.jvmElements.filter(JvmGenericType).filter[t|!t.isInterface].head
		val objectName = "action" + uuidName
		'''
			«actionClass.fullyQualifiedName» «objectName» = new «actionClass.fullyQualifiedName»();
			«objectName».accept(
			«FOR exp: actualParameters.parameters»
				«doInternalToJavaStatement(exp, appendable, true)»
			«ENDFOR»
			);
		'''
	}
	
	def uuidName(){
		UUID.randomUUID.toString.replace("-","")
	}
}
