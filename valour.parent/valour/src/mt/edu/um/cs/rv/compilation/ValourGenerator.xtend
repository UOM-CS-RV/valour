package mt.edu.um.cs.rv.compilation

import javax.inject.Inject
import org.eclipse.xtext.xbase.compiler.JvmModelGenerator
import org.eclipse.xtext.xbase.compiler.XbaseCompiler

class ValourGenerator //implements IGenerator { 
	extends JvmModelGenerator {

	@Inject
	XbaseCompiler xbaseCompiler
	
}
