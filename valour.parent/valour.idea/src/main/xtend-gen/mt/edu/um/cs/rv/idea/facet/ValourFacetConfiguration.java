/**
 * generated by Xtext 2.9.2
 */
package mt.edu.um.cs.rv.idea.facet;

import com.intellij.openapi.components.PersistentStateComponent;
import com.intellij.openapi.components.State;
import com.intellij.openapi.components.Storage;
import com.intellij.openapi.components.StoragePathMacros;
import com.intellij.openapi.components.StorageScheme;
import org.eclipse.xtext.xbase.idea.facet.XbaseFacetConfiguration;
import org.eclipse.xtext.xbase.idea.facet.XbaseGeneratorConfigurationState;

@State(name = "mt.edu.um.cs.rv.ValourGenerator", storages = { @Storage(id = "default", file = StoragePathMacros.PROJECT_FILE), @Storage(id = "dir", file = (StoragePathMacros.PROJECT_CONFIG_DIR + "/ValourGeneratorConfig.xml"), scheme = StorageScheme.DIRECTORY_BASED) })
@SuppressWarnings("all")
public class ValourFacetConfiguration extends XbaseFacetConfiguration implements PersistentStateComponent<XbaseGeneratorConfigurationState> {
}
