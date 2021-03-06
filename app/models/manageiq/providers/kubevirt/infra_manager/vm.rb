#
# Copyright (c) 2017 Red Hat, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

class ManageIQ::Providers::Kubevirt::InfraManager::Vm < ManageIQ::Providers::InfraManager::Vm
  include_concern 'Operations'

  def self.calculate_power_state(raw)
    raw
  end

  #
  # This method is executed in the UI worker. It adds to the queue a task to retrieve the
  # `remote-viewer` configuration file for a virtual machine.
  #
  # @return [Integer] The identifier of the task.
  #
  def queue_generate_remote_viewer_file
    # Create the task options:
    task_options = {
      action: "Generate 'remote-viewer' configuration file for VM '#{name}'"
    }

    # Create the queue options:
    queue_options = {
      class_name: self.class.name,
      instance_id: id,
      method_name: 'generate_remote_viewer_file',
      priority: MiqQueue::HIGH_PRIORITY,
      role: 'ems_operations',
      zone: my_zone,
      args: []
    }

    # Add the task to the queue and return the identifier:
    MiqTask.generic_action_with_callback(task_options, queue_options)
  end

  #
  # This method is executed in the provider worker. It contacts the KubeVirt API to get the details of the connection to
  # the console, and generates the `remote-viewer` configuration file.
  #
  # @return [String] The content of the cofiguration file.
  #
  def generate_remote_viewer_file
    # Retrieve the details of the the virtual machine and the URL of the SPICE proxy:
    vm = nil
    proxy = nil
    ext_management_system.with_provider_connection do |connection|
      vm = connection.vm(name)
      proxy = connection.spice_proxy_url
    end

    # The virtual machine may have multiple graphics device, get the first one that uses the SPICE protocol:
    spice = vm.status.graphics.detect { |graphics| graphics.type == 'spice'}

    # Generate the content of the `remote-viewer` configuration file file:
    file = \
      "[virt-viewer]\n" \
      "type=spice\n" \
      "title=#{name} - Press SHIFT+F12 to Release Cursor\n" \
      "host=#{spice.host}\n" \
      "port=#{spice.port}\n" \
      "proxy=#{proxy}\n" \
      "delete-this-file=1\n" \
      "toggle-fullscreen=shift+f11\n" \
      "release-cursor=shift+f12\n" \
      "secure-attention=ctrl+alt+del\n"

    # Return the generated file:
    file
  end
end
